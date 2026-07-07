#!/usr/bin/env bash
# diagnostics.sh — non-destructive system diagnostics

do_diagnose() {
  echo "=== Telecom Manager Diagnostics ==="
  echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo

  echo "=== Services ==="
  for svc in ssh sshd-httpcustom stunnel4 xray telecom-manager nginx; do
    printf "%-25s " "$svc"
    systemctl is-active "$svc" 2>/dev/null || echo "unknown"
  done

  echo
  echo "=== Listening Ports ==="
  ss -tlnp | grep -E ":${SSH_TARGET_PORT:-22}|:${SSH_COMPAT_PORT:-2222}|:${STUNNEL_PORT:-443}|:${VMESS_PORT:-2053}|:${VLESS_PORT:-8443}|:${PANEL_PORT:-9000}|:${NGINX_PORT:-80}" || echo "  (none matched)"

  echo
  echo "=== Xray Config Permissions ==="
  for f in "$XRAY_CONFIG" "$XRAY_CERT_DIR/server.crt" "$XRAY_CERT_DIR/server.key"; do
    if [ -f "$f" ]; then
      ls -la "$f"
    else
      echo "  missing: $f"
    fi
  done

  echo
  echo "=== Xray Error Log (last 50 lines) ==="
  journalctl -u xray --no-pager -n 50 -p err 2>/dev/null || echo "  (no errors)"

  echo
  echo "=== Xray Access Log (last 50 lines) ==="
  tail -50 /var/log/xray/access.log 2>/dev/null || echo "  (empty or missing)"

  echo
  echo "=== VLESS + VMess Users ==="
  if [ -x /usr/local/sbin/telecomctl ]; then
    /usr/local/sbin/telecomctl xray list-users 2>/dev/null || echo "  (error listing users)"
  else
    echo "  telecomctl not installed"
  fi
}
