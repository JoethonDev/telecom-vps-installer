#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:-install}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() {
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

fail() {
  echo "FATAL: $1" >&2
  exit 1
}

# shellcheck source=lib/preflight.sh
source "$SCRIPT_DIR/lib/preflight.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"
# shellcheck source=lib/ssh.sh
source "$SCRIPT_DIR/lib/ssh.sh"
# shellcheck source=lib/stunnel.sh
source "$SCRIPT_DIR/lib/stunnel.sh"
# shellcheck source=lib/xray.sh
source "$SCRIPT_DIR/lib/xray.sh"
# shellcheck source=lib/users.sh
source "$SCRIPT_DIR/lib/users.sh"
# shellcheck source=lib/telecomctl.sh
source "$SCRIPT_DIR/lib/telecomctl.sh"
# shellcheck source=lib/app_deploy.sh
source "$SCRIPT_DIR/lib/app_deploy.sh"
# shellcheck source=lib/diagnostics.sh
source "$SCRIPT_DIR/lib/diagnostics.sh"
# shellcheck source=lib/backup.sh
source "$SCRIPT_DIR/lib/backup.sh"

do_install() {
  do_preflight
  do_install_packages
  do_setup_firewall
  do_setup_ssh
  do_setup_stunnel
  do_install_xray
  do_configure_xray
  do_install_telecomctl
  do_deploy_app
  log "Installation complete"
}

do_upgrade_infra() {
  log "Upgrading infrastructure components"
  do_install_packages
  do_setup_firewall
  do_upgrade_xray
}

do_repair_permissions() {
  /usr/local/sbin/telecomctl fix-permissions
}

do_uninstall() {
  log "Uninstalling Telecom Manager"

  for unit in telecom-manager.service telecom-manager-maintenance.timer telecom-manager-maintenance.service sshd-httpcustom.service; do
    systemctl stop "$unit" 2>/dev/null || true
    systemctl disable "$unit" 2>/dev/null || true
  done

  rm -f /etc/systemd/system/telecom-manager.service \
    /etc/systemd/system/telecom-manager-maintenance.service \
    /etc/systemd/system/telecom-manager-maintenance.timer \
    /etc/systemd/system/sshd-httpcustom.service \
    /etc/ssh/sshd_config_httpcustom \
    /etc/telecom-manager/telecom-manager.env

  rm -rf /opt/telecom-manager
  rm -f /usr/local/sbin/telecomctl
  rm -f /etc/sudoers.d/telecom-web

  systemctl daemon-reload
  log "Uninstall complete. Shared packages (Xray, stunnel, etc.) were retained."
}

do_setup_firewall() {
  log "Configuring firewall"

  if ufw status 2>/dev/null | grep -q "Status: active"; then
    for rule in "${STUNNEL_PORT}/tcp" "${VMESS_PORT}/tcp" "${VLESS_PORT}/tcp"; do
      if ! ufw status numbered 2>/dev/null | grep -q "${rule}"; then
        ufw allow "$rule" comment "telecom-manager" 2>/dev/null || true
      fi
    done
  else
    echo "UFW is not active; leaving firewall state unchanged."
  fi
}

case "$MODE" in
  install) do_install ;;
  upgrade-app) do_upgrade_app ;;
  upgrade-infra) do_upgrade_infra ;;
  repair-permissions) do_repair_permissions ;;
  diagnose) do_diagnose ;;
  backup) do_backup ;;
  restore) do_restore ;;
  uninstall) do_uninstall ;;
  *)
    echo "Usage: $0 <mode>"
    echo "Modes: install, upgrade-app, upgrade-infra, repair-permissions, diagnose, backup, restore, uninstall"
    exit 1
    ;;
esac
