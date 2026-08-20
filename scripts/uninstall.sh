#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_root
require_command depmod

KERNEL_RELEASE=${KERNEL_RELEASE:-$(uname -r)}
validate_kernel_release "$KERNEL_RELEASE"

TARGET_DIR="/lib/modules/$KERNEL_RELEASE/updates/linux-bluetooth-headset-mic-fix"
TARGET_MODULE="$TARGET_DIR/bluetooth.ko"
STATE_DIR="/var/lib/$PROJECT_NAME/$KERNEL_RELEASE"
STATE_FILE="$STATE_DIR/state"
BACKUP_MODULE="$STATE_DIR/bluetooth.previous.ko"

[[ -f $STATE_FILE ]] || die "no installation state found for $KERNEL_RELEASE"
# The state file contains only a value written by install.sh.
# shellcheck disable=SC1090
source "$STATE_FILE"

case ${had_previous:-} in
  1)
    [[ -f $BACKUP_MODULE ]] || die "previous module backup is missing: $BACKUP_MODULE"
    install -m 0644 "$BACKUP_MODULE" "$TARGET_MODULE"
    log "restored the module that existed before this project was installed"
    ;;
  0)
    rm -f -- "$TARGET_MODULE"
    log "removed this project's module override"
    ;;
  *)
    die "invalid installation state"
    ;;
esac

rm -f -- "$STATE_FILE" "$STATE_DIR/installed.sha256" "$BACKUP_MODULE"
rmdir --ignore-fail-on-non-empty "$STATE_DIR" "$TARGET_DIR" 2>/dev/null || true
depmod "$KERNEL_RELEASE"

log "no live module was unloaded; reboot to complete the rollback"
