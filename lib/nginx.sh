#!/usr/bin/env bash
# nginx.sh — reverse proxy for the web panel

NGINX_SSL_DIR="${NGINX_SSL_DIR:-/etc/nginx/ssl}"

_nginx_gen_cert() {
  local domain="$1"
  mkdir -p "$NGINX_SSL_DIR"
  if [ ! -f "$NGINX_SSL_DIR/$domain.crt" ]; then
    openssl req -x509 -nodes -newkey rsa:2048 \
      -keyout "$NGINX_SSL_DIR/$domain.key" \
      -out "$NGINX_SSL_DIR/$domain.crt" \
      -days 3650 \
      -subj "/CN=$domain" \
      -addext "subjectAltName=DNS:$domain"
    chmod 600 "$NGINX_SSL_DIR/$domain.key"
  fi
}

_nginx_write_config() {
  local domain="$1"
  local has_https=false
  [ -n "$domain" ] && [ "$domain" != "_" ] && has_https=true

  local config=""
  config+="server {\n"
  config+="    listen ${NGINX_PORT:-80};\n"
  config+="    server_name ${domain};\n\n"
  config+="    gzip on;\n"
  config+="    gzip_types text/css application/javascript text/plain;\n\n"
  config+="    location / {\n"
  config+="        proxy_pass http://127.0.0.1:${PANEL_PORT};\n"
  config+="        proxy_http_version 1.1;\n"
  config+="        proxy_set_header Upgrade \$http_upgrade;\n"
  config+="        proxy_set_header Connection \"upgrade\";\n"
  config+="        proxy_set_header Host \$host;\n"
  config+="        proxy_set_header X-Real-IP \$remote_addr;\n"
  config+="        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n"
  config+="        proxy_set_header X-Forwarded-Proto \$scheme;\n"
  config+="    }\n"

  if $has_https; then
    _nginx_gen_cert "$domain"
    config+="}\n\n"
    config+="server {\n"
    config+="    listen ${NGINX_SSL_PORT:-443} ssl;\n"
    config+="    server_name ${domain};\n\n"
    config+="    ssl_certificate ${NGINX_SSL_DIR}/${domain}.crt;\n"
    config+="    ssl_certificate_key ${NGINX_SSL_DIR}/${domain}.key;\n\n"
    config+="    gzip on;\n"
    config+="    gzip_types text/css application/javascript text/plain;\n\n"
    config+="    location / {\n"
    config+="        proxy_pass http://127.0.0.1:${PANEL_PORT};\n"
    config+="        proxy_http_version 1.1;\n"
    config+="        proxy_set_header Upgrade \$http_upgrade;\n"
    config+="        proxy_set_header Connection \"upgrade\";\n"
    config+="        proxy_set_header Host \$host;\n"
    config+="        proxy_set_header X-Real-IP \$remote_addr;\n"
    config+="        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n"
    config+="        proxy_set_header X-Forwarded-Proto \$scheme;\n"
    config+="    }\n"
  fi

  config+="}\n"
  echo -e "$config" > /etc/nginx/sites-available/telecom-manager
}

_free_port() {
  local port="$1"
  local service="${2:-}"
  if ss -tlnp "sport = :$port" 2>/dev/null | grep -q LISTEN; then
    local pid
    pid=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -n "$pid" ]; then
      local svc_name
      svc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "")
      if [ -n "$service" ] && echo "$svc_name" | grep -qi "$service"; then
        systemctl stop "$service" 2>/dev/null || kill "$pid" 2>/dev/null || true
        return 0
      fi
    fi
    return 1
  fi
  return 0
}

do_setup_nginx() {
  log "Setting up nginx reverse proxy"

  local server_name="${PANEL_DOMAIN:-${CONNECTION_DOMAIN:-${TLS_SERVER_NAME:-_}}}"
  local has_https=false
  [ -n "$server_name" ] && [ "$server_name" != "_" ] && has_https=true

  if $has_https; then
    if [ "$NGINX_SSL_PORT" = "$STUNNEL_PORT" ]; then
      if ss -tlnp "sport = :$STUNNEL_PORT" 2>/dev/null | grep -qE "stunnel|stunnel4"; then
        log "Port $STUNNEL_PORT is used by stunnel — moving stunnel to $STUNNEL_FALLBACK_PORT"
        systemctl stop stunnel4 2>/dev/null || true
        local current_accept
        current_accept=$(grep '^accept' /etc/stunnel/stunnel.conf 2>/dev/null | head -1)
        local accept_prefix
        accept_prefix=$(echo "$current_accept" | sed 's/:[0-9]*$//')
        if [ -n "$accept_prefix" ]; then
          sed -i "s/^accept = .*/${accept_prefix}:${STUNNEL_FALLBACK_PORT}/" /etc/stunnel/stunnel.conf
        fi
        STUNNEL_PORT="$STUNNEL_FALLBACK_PORT"
        systemctl start stunnel4 2>/dev/null || true
        ufw allow "${STUNNEL_FALLBACK_PORT}/tcp" comment "telecom-manager" 2>/dev/null || true
      fi
    fi
  fi

  _nginx_write_config "$server_name"

  ln -sf /etc/nginx/sites-available/telecom-manager /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default

  if nginx -t 2>/dev/null; then
    systemctl enable nginx
    systemctl restart nginx
  else
    nginx -t 2>&1 || true
    fail "nginx config validation failed"
  fi
}

do_nginx_reconfigure() {
  local domain="${1:-${PANEL_DOMAIN:-${CONNECTION_DOMAIN:-${TLS_SERVER_NAME:-_}}}}"
  _nginx_write_config "$domain"

  if nginx -t 2>/dev/null; then
    systemctl reload nginx || systemctl restart nginx
  else
    nginx -t 2>&1 || true
    fail "nginx config validation failed"
  fi
}
