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

  [[ $release =~ ^6\.17\.0-[0-9]+-generic$ ]] ||
    die "unsupported kernel '$release'; automated builds currently support Ubuntu generic 6.17 only"
}

secure_boot_enabled() {
  if command -v mokutil >/dev/null 2>&1; then
    mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled'
    return
  fi

  return 1
}
