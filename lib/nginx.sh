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
    config+="    listen 443 ssl;\n"
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

do_setup_nginx() {
  log "Setting up nginx reverse proxy"

  local server_name="${PANEL_DOMAIN:-${CONNECTION_DOMAIN:-${TLS_SERVER_NAME:-_}}}"
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
