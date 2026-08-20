#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

OUTPUT=${1:-"bluetooth-mic-diagnostics-$(date -u +%Y%m%dT%H%M%SZ).txt"}
MAC_PATTERN='([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}'
HOST_NAME=$(hostname 2>/dev/null || true)
USER_NAME=$(id -un 2>/dev/null || true)

escape_sed_pattern() {
  printf '%s' "$1" | sed -e 's/[][\/.*^$\\]/\\&/g'
}

HOST_PATTERN=$(escape_sed_pattern "$HOST_NAME")
USER_PATTERN=$(escape_sed_pattern "$USER_NAME")

section() {
  printf '\n## %s\n' "$1"
}

run_optional() {
  local label=$1
  shift
  section "$label"
  if command -v "$1" >/dev/null 2>&1; then
    "$@" 2>&1 || true
  else
    printf 'command not available: %s\n' "$1"
  fi
}

collect() {
  printf '# Linux Bluetooth microphone diagnostics\n'
  printf 'generated_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  section "Operating system"
  uname -srvm
  if [[ -r /etc/os-release ]]; then
    grep -E '^(NAME|VERSION|ID|VERSION_ID)=' /etc/os-release || true
  fi

  run_optional "Bluetooth USB devices" lsusb
  run_optional "Bluetooth controller" bluetoothctl show
  run_optional "PipeWire version" pipewire --version
  run_optional "WirePlumber version" wireplumber --version
  run_optional "BlueZ version" bluetoothd --version
  run_optional "Audio server" pactl info
  run_optional "PipeWire status" wpctl status

  section "Bluetooth module"
  modinfo -n bluetooth 2>&1 || true
  modinfo -F vermagic bluetooth 2>&1 || true
  modinfo -F signer bluetooth 2>&1 || true
  if [[ -r /sys/module/bluetooth/parameters/disable_esco ]]; then
    printf 'disable_esco='
    cat /sys/module/bluetooth/parameters/disable_esco
  fi

  section "Relevant kernel log"
  journalctl -k --no-pager --since '-30 min' 2>&1 |
    grep -Ei 'bluetooth|btusb|SCO packet|eSCO|unknown connection|LMP parameter|mic-fix|freebuds-fix' || true

  section "Relevant user audio log"
  journalctl --user --no-pager --since '-30 min' 2>&1 |
    grep -Ei 'pipewire|wireplumber|bluez|bluetooth|headset|handsfree|mSBC|SCO' || true
}

umask 077
collect |
  sed -E \
    -e "s/$MAC_PATTERN/<redacted-bt-mac>/g" \
    -e "${HOST_PATTERN:+s/$HOST_PATTERN/<redacted-host>/g}" \
    -e "${USER_PATTERN:+s/$USER_PATTERN/<redacted-user>/g}" \
    > "$OUTPUT"
log "wrote $OUTPUT"
warn "review the file before publishing; device models and system versions are intentionally retained"
