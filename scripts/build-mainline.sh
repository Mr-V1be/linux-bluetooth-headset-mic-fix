#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build the delayed-eSCO bluetooth.ko against a mainline/stable tag that
# matches the running kernel (e.g. Pop!_OS 7.2.15 -> v7.2.15).
#
# Use this when the distro linux-source package is empty or missing
# (Pop!_OS ships a stub linux-source-*.deb) but linux-headers match
# an upstream stable release.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_command git
require_command make
require_command modinfo
require_command patch
require_command tar

KERNEL_RELEASE=${KERNEL_RELEASE:-$(uname -r)}
validate_kernel_release "$KERNEL_RELEASE"

HEADERS_DIR="/lib/modules/$KERNEL_RELEASE/build"
[[ -d $HEADERS_DIR ]] ||
  die "matching headers are missing; install linux-headers-$KERNEL_RELEASE"

# Pop!_OS: 7.2.15-76070215-generic -> v7.2.15
BASE_VERSION=${KERNEL_RELEASE%%-*}
MAINLINE_TAG=${MAINLINE_TAG:-"v${BASE_VERSION}"}

PATCH_SERIES_DIR=${PATCH_SERIES_DIR:-"$REPO_ROOT/patches/mainline-7.2"}
[[ -f $PATCH_SERIES_DIR/series ]] ||
  die "patch series missing: $PATCH_SERIES_DIR/series"

BUILD_PARENT=${BUILD_PARENT:-"$REPO_ROOT/build"}
DIST_DIR="$REPO_ROOT/dist/$KERNEL_RELEASE"
SRC_CACHE=${SRC_CACHE:-"$BUILD_PARENT/linux-stable-sparse"}

mkdir -p "$BUILD_PARENT" "$DIST_DIR"
WORK_DIR=$(mktemp -d "$BUILD_PARENT/build-mainline-$KERNEL_RELEASE.XXXXXXXX")

cleanup() {
  if [[ ${KEEP_BUILD:-0} == 1 ]]; then
    log "keeping build directory: $WORK_DIR"
  else
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT

log "fetching net/bluetooth from stable tag $MAINLINE_TAG"
if [[ ! -d $SRC_CACHE/.git ]]; then
  mkdir -p "$(dirname -- "$SRC_CACHE")"
  git clone --depth 1 --filter=blob:none --sparse \
    https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
    "$SRC_CACHE"
  (
    cd "$SRC_CACHE"
    git sparse-checkout set net/bluetooth
  )
fi

(
  cd "$SRC_CACHE"
  git fetch --depth 1 origin "refs/tags/${MAINLINE_TAG}:refs/tags/${MAINLINE_TAG}" 2>/dev/null ||
    git fetch --depth 1 origin tag "$MAINLINE_TAG"
  git checkout -f "$MAINLINE_TAG"
)

[[ -d $SRC_CACHE/net/bluetooth ]] ||
  die "net/bluetooth missing after checkout of $MAINLINE_TAG"

mkdir -p "$WORK_DIR/source/net"
cp -a "$SRC_CACHE/net/bluetooth" "$WORK_DIR/source/net/bluetooth"

while IFS= read -r patch_name; do
  [[ -n $patch_name && $patch_name != \#* ]] || continue
  patch_path="$PATCH_SERIES_DIR/$patch_name"
  [[ -f $patch_path ]] || die "patch listed in series is missing: $patch_name"
  log "applying $patch_name"
  patch --directory="$WORK_DIR/source" --strip=1 --batch --forward < "$patch_path"
done < "$PATCH_SERIES_DIR/series"

log "building bluetooth.ko for $KERNEL_RELEASE (sources: $MAINLINE_TAG)"
make \
  -C "$HEADERS_DIR" \
  "M=$WORK_DIR/source/net/bluetooth" \
  -j"${BUILD_JOBS:-$(nproc)}" \
  modules

MODULE="$WORK_DIR/source/net/bluetooth/bluetooth.ko"
[[ -f $MODULE ]] || die "build completed without bluetooth.ko"

MODULE_NAME=$(modinfo -F name "$MODULE")
MODULE_VERMAGIC=$(modinfo -F vermagic "$MODULE")
[[ $MODULE_NAME == bluetooth ]] || die "unexpected module name: $MODULE_NAME"
[[ ${MODULE_VERMAGIC%% *} == "$KERNEL_RELEASE" ]] ||
  die "module vermagic '$MODULE_VERMAGIC' does not match $KERNEL_RELEASE"

install -m 0644 "$MODULE" "$DIST_DIR/bluetooth.ko"
(
  cd "$DIST_DIR"
  sha256sum bluetooth.ko > SHA256SUMS
)

log "build successful: $DIST_DIR/bluetooth.ko"
log "vermagic: $MODULE_VERMAGIC"
log "next step: sudo ./scripts/install.sh"
