#!/usr/bin/env bash
# packages.sh — system package installation

do_install_packages() {
  log "Installing system packages"

  apt_retry env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl unzip openssl ufw stunnel4 ca-certificates sqlite3 \
    python3 python3-venv python3-pip \
    openssh-server openssh-client git nginx

  if [ -n "${TIMEZONE:-}" ]; then
    timedatectl set-timezone "$TIMEZONE" 2>/dev/null || echo "Warning: Could not set timezone"
  fi
}
