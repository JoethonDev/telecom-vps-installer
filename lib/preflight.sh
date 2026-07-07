#!/usr/bin/env bash
# preflight.sh — system validation, prompts, conflict detection

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root." >&2
    exit 1
  fi
}

require_supported_os() {
  if [ ! -f /etc/os-release ]; then
    fail "Cannot detect OS. Supported: Debian 12+ and Ubuntu 24.04+."
  fi
  # shellcheck source=/dev/null
  . /etc/os-release
  ID="${ID:-linux}"
  VERSION_ID="${VERSION_ID:-0}"
  local major minor
  major="${VERSION_ID%%.*}"
  minor="${VERSION_ID#*.}"
  case "$ID" in
    debian)
      if ! [ "$major" -ge 12 ] 2>/dev/null; then
        fail "Unsupported Debian $VERSION_ID (expected Debian 12 or newer)."
      fi
      ;;
    ubuntu)
      if ! [ "$major" -gt 24 ] 2>/dev/null && ! { [ "$major" -eq 24 ] 2>/dev/null && [ "${minor%%.*}" -ge 4 ] 2>/dev/null; }; then
        fail "Unsupported Ubuntu $VERSION_ID (expected Ubuntu 24.04 or newer)."
      fi
      ;;
    *)
      fail "Unsupported OS: $ID. Supported: Debian 12+ and Ubuntu 24.04+."
      ;;
  esac
}

require_commands() {
  local missing=""
  for cmd in apt-get systemctl git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing="$missing $cmd"
    fi
  done
  if [ -n "$missing" ]; then
    fail "Missing required commands:$missing"
  fi
}

apt_retry() {
  local attempt
  for ((attempt = 1; attempt <= 30; attempt++)); do
    if "$@"; then
      return 0
    fi
    echo "Package manager busy; retrying in 10s ($attempt/30)..."
    sleep 10
  done
  fail "Package manager did not succeed: $*"
}

check_port_free() {
  local port="$1"
  if ss -tlnp "sport = :$port" 2>/dev/null | grep -q LISTEN; then
    return 1
  fi
  return 0
}

validate_domain() {
  local val="$1"
  [ -z "$val" ] && return 0
  echo "$val" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
}

validate_port() {
  local val="$1"
  [ "$val" -ge 1 ] 2>/dev/null && [ "$val" -le 65535 ] 2>/dev/null
}

validate_username() {
  local val="$1"
  echo "$val" | grep -qE '^[a-zA-Z0-9_][a-zA-Z0-9_-]{2,31}$'
}

validate_timezone() {
  local val="$1"
  [ -z "$val" ] && return 0
  [ -f "/usr/share/zoneinfo/$val" ] 2>/dev/null
}

detect_public_ip() {
  PUBLIC_IP=""
  PUBLIC_IPV6=""
  local ip ip6
  ip=$(ip -4 route get 1 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1 || true)
  if [ -n "$ip" ] && [ "$ip" != "1.0.0.0" ] && [[ "$ip" != 10.* && "$ip" != 100.6[4-9].* && "$ip" != 100.[7-9][0-9].* && "$ip" != 100.1[0-1][0-9].* && "$ip" != 100.12[0-7].* && "$ip" != 127.* && "$ip" != 169.254.* && "$ip" != 172.1[6-9].* && "$ip" != 172.2[0-9].* && "$ip" != 172.3[0-1].* && "$ip" != 192.168.* ]]; then
    PUBLIC_IP="$ip"
  fi
  ip6=$(ip -6 route get 2001:4860:4860::8888 2>/dev/null | grep -oP 'src \K[0-9a-f:]+' | head -1 || true)
  if [ -n "$ip6" ] && [[ "$ip6" != fe80:* && "$ip6" != fd* && "$ip6" != fc* && "$ip6" != ::1 ]]; then
    PUBLIC_IPV6="$ip6"
  fi
  if [ -z "$PUBLIC_IP" ]; then
    ip=$(curl -fs --max-time 5 https://api.ipify.org 2>/dev/null || curl -fs --max-time 5 https://icanhazip.com 2>/dev/null || true)
    if [ -n "$ip" ]; then
      PUBLIC_IP="$ip"
    fi
  fi
}

check_disk_space() {
  local needed="$1"
  local avail
  avail=$(df -m /opt 2>/dev/null | awk 'NR==2 {print $4}')
  if [ -z "$avail" ]; then
    avail=$(df -m / | awk 'NR==2 {print $4}')
  fi
  if [ "$avail" -lt "$needed" ]; then
    return 1
  fi
  return 0
}

check_outbound_connectivity() {
  local hosts="github.com google.com cloudflare.com"
  local ok=0
  for host in $hosts; do
    if timeout 5 curl -fs -o /dev/null "https://$host" 2>/dev/null; then
      ok=1
      break
    fi
  done
  [ "$ok" -eq 1 ]
}

do_preflight() {
  require_root
  require_supported_os
  require_commands
  apt_retry apt-get update
  apt_retry env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl iproute2
  detect_public_ip
  if ! check_disk_space 1024; then
    fail "Insufficient disk space. At least 1 GB free required."
  fi
  if ! check_outbound_connectivity; then
    echo "Warning: Outbound connectivity check failed."
  fi
}
