#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER_REPO_URL="${INSTALLER_REPO_URL:-https://github.com/JoethonDev/telecom-vps-installer}"
INSTALLER_REF="${INSTALLER_REF:-main}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching installer from $INSTALLER_REPO_URL (ref: $INSTALLER_REF)..."
curl -fsSL "$INSTALLER_REPO_URL/archive/refs/heads/$INSTALLER_REF.tar.gz" | tar -xz -C "$TMPDIR"
mv "$TMPDIR/telecom-vps-installer-$INSTALLER_REF" "$TMPDIR/installer"
chmod +x "$TMPDIR/installer/install.sh"
exec "$TMPDIR/installer/install.sh" "$@"
