#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER_REPO_URL="${INSTALLER_REPO_URL:-https://github.com/JoethonDev/telecom-vps-installer}"
INSTALLER_REF="${INSTALLER_REF:-main}"
INSTALLER_VERSION="${INSTALLER_VERSION:-}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching installer from $INSTALLER_REPO_URL (ref: $INSTALLER_REF)..."
git clone --depth 1 -b "$INSTALLER_REF" "$INSTALLER_REPO_URL" "$TMPDIR/installer"
exec "$TMPDIR/installer/install.sh" "$@"
