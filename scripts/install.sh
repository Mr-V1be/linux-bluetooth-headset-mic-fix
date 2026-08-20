#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_root
require_command depmod
require_command modinfo
require_command sha256sum

KERNEL_RELEASE=${KERNEL_RELEASE:-$(uname -r)}
validate_kernel_release "$KERNEL_RELEASE"

SOURCE_MODULE=${SOURCE_MODULE:-"$REPO_ROOT/dist/$KERNEL_RELEASE/bluetooth.ko"}
SOURCE_MODULE=$(realpath -- "$SOURCE_MODULE")
[[ -f $SOURCE_MODULE ]] ||
  die "built module not found: $SOURCE_MODULE (run ./scripts/build-ubuntu.sh first)"

MODULE_NAME=$(modinfo -F name "$SOURCE_MODULE")
MODULE_VERMAGIC=$(modinfo -F vermagic "$SOURCE_MODULE")
MODULE_SIGNER=$(modinfo -F signer "$SOURCE_MODULE")
[[ $MODULE_NAME == bluetooth ]] || die "refusing to install module named '$MODULE_NAME'"
[[ ${MODULE_VERMAGIC%% *} == "$KERNEL_RELEASE" ]] ||
  die "module was built for '${MODULE_VERMAGIC%% *}', not '$KERNEL_RELEASE'"

if secure_boot_enabled && [[ -z $MODULE_SIGNER ]]; then
  die "Secure Boot is enabled and the module is unsigned; sign it first or use a system where Secure Boot policy permits it"
fi

TARGET_DIR="/lib/modules/$KERNEL_RELEASE/updates/linux-bluetooth-headset-mic-fix"
TARGET_MODULE="$TARGET_DIR/bluetooth.ko"
STATE_DIR="/var/lib/$PROJECT_NAME/$KERNEL_RELEASE"
STATE_FILE="$STATE_DIR/state"
BACKUP_MODULE="$STATE_DIR/bluetooth.previous.ko"

mkdir -p "$TARGET_DIR" "$STATE_DIR"

if [[ ! -f $STATE_FILE ]]; then
  if [[ -f $TARGET_MODULE ]]; then
    install -m 0644 "$TARGET_MODULE" "$BACKUP_MODULE"
    printf 'had_previous=1\n' > "$STATE_FILE"
  else
    printf 'had_previous=0\n' > "$STATE_FILE"
  fi
fi

install -m 0644 "$SOURCE_MODULE" "$TARGET_MODULE"
sha256sum "$TARGET_MODULE" > "$STATE_DIR/installed.sha256"
depmod "$KERNEL_RELEASE"

RESOLVED_MODULE=$(modinfo -k "$KERNEL_RELEASE" -n bluetooth)
if [[ $RESOLVED_MODULE != "$TARGET_MODULE" ]]; then
  warn "depmod resolves bluetooth to $RESOLVED_MODULE instead of $TARGET_MODULE"
  warn "another module override may have higher priority; inspect it before rebooting"
else
  log "installed module for $KERNEL_RELEASE"
fi

log "no live module was unloaded; reboot to activate the fix"
log "rollback: sudo ./scripts/uninstall.sh && sudo reboot"
