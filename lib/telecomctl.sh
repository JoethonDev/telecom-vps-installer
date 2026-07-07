#!/usr/bin/env bash
# telecomctl.sh — install telecomctl to /usr/local/sbin

do_install_telecomctl() {
  log "Installing telecomctl to /usr/local/sbin/telecomctl"

  cp "$SCRIPT_DIR/sbin/telecomctl" /usr/local/sbin/telecomctl
  chown root:root /usr/local/sbin/telecomctl
  chmod 0755 /usr/local/sbin/telecomctl

  # Create sudoers rule for telecom-web user
  cat > /etc/sudoers.d/telecom-web <<'SUDO'
telecom-web ALL=(root) NOPASSWD: /usr/local/sbin/telecomctl
SUDO
  chmod 0440 /etc/sudoers.d/telecom-web
  visudo -cf /etc/sudoers.d/telecom-web
}
