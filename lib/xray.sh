#!/usr/bin/env bash
# xray.sh — Xray installation and configuration

do_install_xray() {
  log "Installing Xray"

  local version="${XRAY_VERSION:-v26.3.27}"
  local install_commit="e741a4f56d368afbb9e5be3361b40c4552d3710d"
  local install_sha256="7f70c95f6b418da8b4f4883343d602964915e28748993870fd554383afdbe555"

  local script="/tmp/xray-install-release.sh"
  local logfile
  logfile="$(mktemp /tmp/xray-install.XXXXXX.log)"

  curl -fsSL -o "$script" \
    "https://raw.githubusercontent.com/XTLS/Xray-install/$install_commit/install-release.sh"
  echo "$install_sha256  $script" | sha256sum -c -

  set +e
  bash "$script" install --version "$version" >"$logfile" 2>&1
  local rc=$?
  set -e

  if [ ! -x "$(command -v xray)" ]; then
    cat "$logfile" >&2 || true
    fail "Xray installer failed: binary not found"
  fi

  rm -f "$logfile" "$script"
}

do_configure_xray() {
  log "Configuring Xray"

  mkdir -p "$XRAY_CERT_DIR"
  mkdir -p /var/log/xray

  if [ ! -f "$XRAY_CERT_DIR/server.crt" ]; then
    openssl req -x509 -nodes -newkey rsa:2048 \
      -keyout "$XRAY_CERT_DIR/server.key" \
      -out "$XRAY_CERT_DIR/server.crt" \
      -days 3650 \
      -subj "/CN=${TLS_SERVER_NAME}" \
      -addext "subjectAltName=DNS:${TLS_SERVER_NAME}"
  fi

  chmod 755 "$XRAY_CERT_DIR"
  chmod 644 "$XRAY_CERT_DIR/server.crt"

  local xray_user
  xray_user="$(systemctl show xray.service -P User 2>/dev/null || echo nobody)"
  chown "$xray_user" "$XRAY_CERT_DIR/server.key"
  chmod 600 "$XRAY_CERT_DIR/server.key"
  chown "$xray_user" /var/log/xray

  local listen_addr="0.0.0.0"
  if [ -n "${PUBLIC_IPV6:-}" ]; then
    listen_addr="::"
  fi

  cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log"
  },
  "inbounds": [
    {
      "tag": "vmess-tcp-tls",
      "port": $VMESS_PORT,
      "listen": "$listen_addr",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tcpSettings": {
          "header": {
            "type": "none"
          }
        },
        "tlsSettings": {
          "serverName": "$TLS_SERVER_NAME",
          "certificates": [
            {
              "certificateFile": "$XRAY_CERT_DIR/server.crt",
              "keyFile": "$XRAY_CERT_DIR/server.key"
            }
          ]
        }
      }
    },
    {
      "tag": "vless-tcp-tls-vision",
      "port": $VLESS_PORT,
      "listen": "$listen_addr",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tcpSettings": {
          "header": {
            "type": "none"
          }
        },
        "tlsSettings": {
          "serverName": "$TLS_SERVER_NAME",
          "certificates": [
            {
              "certificateFile": "$XRAY_CERT_DIR/server.crt",
              "keyFile": "$XRAY_CERT_DIR/server.key"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

  xray run -test -config "$XRAY_CONFIG"
  touch /var/log/xray/access.log
  chown "$xray_user" /var/log/xray/access.log

  systemctl enable xray >/dev/null 2>&1 || true
  if ! systemctl restart xray >/dev/null 2>&1; then
    systemctl status xray --no-pager >&2 || true
    fail "Xray failed to start"
  fi
}

do_upgrade_xray() {
  log "Upgrading Xray"
  bash /tmp/xray-install-release.sh install --version "${XRAY_VERSION:-v26.3.27}" >/dev/null 2>&1 || true
}
