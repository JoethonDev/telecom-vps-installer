#!/usr/bin/env bash
# app_deploy.sh — Flask application deployment

do_deploy_app() {
  log "Deploying Telecom Manager application"

  local release_id
  release_id="r$(date +%Y%m%d%H%M%S)"
  local releases_dir="/opt/telecom-manager/releases"
  local release_dir="$releases_dir/$release_id"
  local current_link="/opt/telecom-manager/current"

  mkdir -p "$releases_dir" /etc/telecom-manager /var/lib/telecom-manager /var/log/telecom-manager /var/lib/telecom-manager/backups

  local app_repo="${APP_REPO_URL:-https://github.com/JoethonDev/telecom-manager-app}"
  local app_ref="${APP_REF:-main}"

  git clone --depth 1 -b "$app_ref" "$app_repo" "$release_dir" 2>/dev/null || {
    mkdir -p "$release_dir"
    cp -r "$SCRIPT_DIR/../telecom-manager-app/"* "$release_dir/" 2>/dev/null || true
  }

  if [ -d "$current_link/venv" ]; then
    cp -a "$current_link/venv" "$release_dir/venv"
  else
    python3 -m venv "$release_dir/venv"
  fi
  source "$release_dir/venv/bin/activate"

  pip install --no-input -r "$release_dir/requirements.txt" || \
    pip install "Flask==3.1.3" "gunicorn==26.0.0" "Werkzeug==3.1.8"

  cat > /etc/telecom-manager/telecom-manager.env <<EOF
MANAGER_DOMAIN=${CONNECTION_DOMAIN:-}
PANEL_DOMAIN=${PANEL_DOMAIN:-}
VMESS_PORT=${VMESS_PORT:-2053}
VLESS_PORT=${VLESS_PORT:-8443}
VLESS_FLOW=${VLESS_FLOW:-xtls-rprx-vision}
TLS_SERVER_NAME=${TLS_SERVER_NAME:-localhost}
SSH_TARGET_PORT=${SSH_TARGET_PORT:-22}
PUBLIC_IP=${PUBLIC_IP:-}
PUBLIC_IPV6=${PUBLIC_IPV6:-}
MANAGER_DB=/var/lib/telecom-manager/manager.db
PANEL_PORT=${PANEL_PORT:-9000}
FLASK_SECRET=${FLASK_SECRET:-}
ADMIN_USER=${PANEL_ADMIN_USER:-admin}
ADMIN_PASSWORD_HASH=$(python3 -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('admin'))")
EOF
  chmod 600 /etc/telecom-manager/telecom-manager.env

  cd "$release_dir"
  python manage.py migrate 2>/dev/null || true
  python manage.py create-admin 2>/dev/null || true

  rm -f "$current_link"
  ln -sf "$release_dir" "$current_link"

  cat > /etc/systemd/system/telecom-manager.service <<SRV
[Unit]
Description=Telecom VPS Manager
After=network.target ssh.service xray.service stunnel4.service

[Service]
User=telecom-web
Group=telecom-web
EnvironmentFile=/etc/telecom-manager/telecom-manager.env
WorkingDirectory=$current_link
UMask=0077
PrivateTmp=true
NoNewPrivileges=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true
RestrictRealtime=true
ExecStart=$current_link/venv/bin/gunicorn -w 1 -b 127.0.0.1:\${PANEL_PORT} telecom_manager.app:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SRV

  systemctl daemon-reload
  systemctl enable telecom-manager
  systemctl restart telecom-manager

  local releases
  releases=($(ls -1d "$releases_dir"/r* 2>/dev/null | sort -r))
  if [ ${#releases[@]} -gt 2 ]; then
    for old in "${releases[@]:2}"; do
      rm -rf "$old"
    done
  fi
}

do_upgrade_app() {
  log "Upgrading Telecom Manager application"

  local current_link="/opt/telecom-manager/current"
  local releases_dir="/opt/telecom-manager/releases"
  local release_id
  release_id="r$(date +%Y%m%d%H%M%S)"
  local release_dir="$releases_dir/$release_id"

  local app_repo="${APP_REPO_URL:-https://github.com/JoethonDev/telecom-manager-app}"
  local app_ref="${APP_REF:-main}"
  git clone --depth 1 -b "$app_ref" "$app_repo" "$release_dir"

  if [ -d "$current_link/venv" ]; then
    cp -a "$current_link/venv" "$release_dir/venv"
  else
    python3 -m venv "$release_dir/venv"
  fi
  source "$release_dir/venv/bin/activate"

  pip install --no-input -r "$release_dir/requirements.txt" || \
    pip install "Flask==3.1.3" "gunicorn==26.0.0" "Werkzeug==3.1.8"

  cd "$release_dir"
  python manage.py migrate
  python manage.py health-check 2>/dev/null || {
    log "Health check failed, aborting upgrade"
    rm -rf "$release_dir"
    exit 1
  }

  rm -f "$current_link"
  ln -sf "$release_dir" "$current_link"
  systemctl restart telecom-manager

  local releases
  releases=($(ls -1d "$releases_dir"/r* 2>/dev/null | sort -r))
  if [ ${#releases[@]} -gt 2 ]; then
    for old in "${releases[@]:2}"; do
      rm -rf "$old"
    done
  fi

  log "Upgrade complete: $release_id"
}
