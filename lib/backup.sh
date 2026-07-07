#!/usr/bin/env bash
# backup.sh — database backup and restore

do_backup() {
  local db="/var/lib/telecom-manager/manager.db"
  local bk_dir="/var/lib/telecom-manager/backups"
  local ts
  ts="$(date +%s)"
  local bk_path="$bk_dir/manager.db.$ts"

  mkdir -p "$bk_dir"
  if [ -f "$db" ]; then
    sqlite3 "$db" ".backup '$bk_path'"
    sqlite3 "$bk_path" "PRAGMA integrity_check;" | grep -q "^ok$" || {
      echo "Backup integrity check failed" >&2
      rm -f "$bk_path"
      exit 1
    }
    echo "Backup: $bk_path"
  else
    echo "Database not found" >&2
    exit 1
  fi

  # Keep last 7
  local bks
  mapfile -t bks < <(ls -1t "$bk_dir"/manager.db.* 2>/dev/null || true)
  if [ ${#bks[@]} -gt 7 ]; then
    for old in "${bks[@]:7}"; do
      rm -f "$old"
    done
  fi
}

do_restore() {
  local db="/var/lib/telecom-manager/manager.db"
  local bk_path="${1:-}"
  if [ -z "$bk_path" ]; then
    echo "Usage: $0 restore <backup-file>"
    exit 1
  fi
  if [ ! -f "$bk_path" ]; then
    echo "Backup not found: $bk_path" >&2
    exit 1
  fi
  sqlite3 "$bk_path" "PRAGMA integrity_check;" | grep -q "^ok$" || {
    echo "Backup integrity check failed" >&2
    exit 1
  }
  systemctl stop telecom-manager
  cp "$bk_path" "$db"
  systemctl start telecom-manager
  echo "Restored: $bk_path"
}
