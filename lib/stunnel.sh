#!/usr/bin/env bash
# stunnel.sh — stunnel SSH SSL configuration

do_setup_stunnel() {
  log "Configuring stunnel SSH SSL on port ${STUNNEL_PORT}"

  mkdir -p /etc/stunnel/certs /run/stunnel4 /var/log/stunnel4
  touch /var/log/stunnel4/stunnel.log

  if [ ! -f /etc/stunnel/stunnel.pem ]; then
    openssl req -x509 -nodes -newkey rsa:2048 \
      -keyout /etc/stunnel/certs/stunnel.key \
      -out /etc/stunnel/certs/stunnel.crt \
      -days 3650 \
      -subj "/CN=${TLS_SERVER_NAME}" \
      -addext "subjectAltName=DNS:${TLS_SERVER_NAME}"

    cat /etc/stunnel/certs/stunnel.key /etc/stunnel/certs/stunnel.crt > /etc/stunnel/stunnel.pem
    chmod 600 /etc/stunnel/stunnel.pem
  fi

  sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/stunnel4 || true

  local accept_addr="0.0.0.0"
  if [ -n "${PUBLIC_IPV6:-}" ]; then
    accept_addr="::"
  fi

  cat > /etc/stunnel/stunnel.conf <<EOF
pid = /run/stunnel4/stunnel.pid
foreground = no
debug = 5
output = /var/log/stunnel4/stunnel.log

[ssh_tls]
accept = ${accept_addr}:${STUNNEL_PORT}
connect = 127.0.0.1:${SSH_COMPAT_PORT}
cert = /etc/stunnel/stunnel.pem
TIMEOUTclose = 0
EOF

  systemctl enable stunnel4
  if ! systemctl restart stunnel4; then
    systemctl status stunnel4 --no-pager >&2 || true
    journalctl -xeu stunnel4 --no-pager >&2 || true
    fail "stunnel4 failed to start."
  fi
}
