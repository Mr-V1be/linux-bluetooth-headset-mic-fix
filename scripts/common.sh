#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -Eeuo pipefail

PROJECT_NAME="linux-bluetooth-headset-mic-fix"

log() {
  printf '[%s] %s\n' "$PROJECT_NAME" "$*"
}

warn() {
  printf '[%s] warning: %s\n' "$PROJECT_NAME" "$*" >&2
}

die() {
  printf '[%s] error: %s\n' "$PROJECT_NAME" "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "run this command as root (for example with sudo)"
}

validate_kernel_release() {
  local release=$1

  # Ubuntu 6.17 (original automated build)
  if [[ $release =~ ^6\.17\.0-[0-9]+-generic$ ]]; then
    return 0
  fi
  # Pop!_OS / System76 7.2.x (mainline-based bluetooth.ko via build-mainline.sh)
  if [[ $release =~ ^7\.2\.[0-9]+-76070[0-9]+-generic$ ]]; then
    return 0
  fi
  die "unsupported kernel '$release'; supported: Ubuntu 6.17 generic or Pop!_OS 7.2.x System76"
}

secure_boot_enabled() {
  if command -v mokutil >/dev/null 2>&1; then
    mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'
    return
  fi

  return 1
}
