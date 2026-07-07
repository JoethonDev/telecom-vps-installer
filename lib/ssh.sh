#!/usr/bin/env bash
# ssh.sh — SSH compatibility listener configuration

do_setup_ssh() {
  log "Configuring SSH compatibility listener"

  mkdir -p /run/sshd

  # Validate main SSH config first
  sshd -t

  groupadd -f telecom-users

  # Write managed SSH policy for telecom-users group
  local cfg="/etc/ssh/sshd_config"
  local tmp restore_copy
  restore_copy="$(mktemp)"
  cp "$cfg" "$restore_copy"

  # Remove any existing managed block
  tmp="$(mktemp)"
  awk '
    /^# BEGIN TELECOM-MANAGER MANAGED USERS$/ {skip=1; next}
    /^# END TELECOM-MANAGER MANAGED USERS$/ {skip=0; next}
    skip != 1 {print}
  ' "$cfg" > "$tmp"
  cat "$tmp" > "$cfg"
  rm -f "$tmp"

  cat >> "$cfg" <<'EOF_SSH_POLICY'

# BEGIN TELECOM-MANAGER MANAGED USERS
Match Group telecom-users
    PasswordAuthentication yes
    KbdInteractiveAuthentication yes
    AllowTcpForwarding yes
    X11Forwarding no
    AllowAgentForwarding no
    PermitTunnel yes
# END TELECOM-MANAGER MANAGED USERS
EOF_SSH_POLICY

  if ! sshd -t; then
    cat "$restore_copy" > "$cfg"
    rm -f "$restore_copy"
    fail "Managed OpenSSH policy failed validation; original restored."
  fi
  rm -f "$restore_copy"

  # Restart main SSH
  if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
    true
  fi

  # Create localhost-only SSH compat config
  cat > /etc/ssh/sshd_config_httpcustom <<EOF_SSHD_COMPAT
Port ${SSH_COMPAT_PORT}
ListenAddress 127.0.0.1

DenyUsers root
AllowGroups telecom-users
PasswordAuthentication yes
KbdInteractiveAuthentication yes
ChallengeResponseAuthentication yes
UsePAM yes

AllowTcpForwarding yes
X11Forwarding no
AllowAgentForwarding no
PermitTunnel yes
PermitTTY yes

PidFile /run/sshd-httpcustom.pid

HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
EOF_SSHD_COMPAT

  /usr/sbin/sshd -t -f /etc/ssh/sshd_config_httpcustom

  cat > /etc/systemd/system/sshd-httpcustom.service <<'EOF_SSHD_UNIT'
[Unit]
Description=Telecom Manager localhost SSH compatibility listener
After=network.target ssh.service

[Service]
ExecStartPre=/usr/bin/mkdir -p /run/sshd
ExecStart=/usr/sbin/sshd -D -f /etc/ssh/sshd_config_httpcustom
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF_SSHD_UNIT

  systemctl daemon-reload
  systemctl enable sshd-httpcustom
  systemctl restart sshd-httpcustom
}
