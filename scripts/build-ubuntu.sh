#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_command apt-get
require_command bzip2
require_command dpkg-deb
require_command dpkg-query
require_command make
require_command modinfo
require_command patch
require_command sha256sum
require_command tar

KERNEL_RELEASE=${KERNEL_RELEASE:-$(uname -r)}
validate_kernel_release "$KERNEL_RELEASE"

HEADERS_DIR="/lib/modules/$KERNEL_RELEASE/build"
[[ -d $HEADERS_DIR ]] ||
  die "matching headers are missing; install linux-headers-$KERNEL_RELEASE"

HEADER_PACKAGE="linux-headers-$KERNEL_RELEASE"
HEADER_VERSION=$(dpkg-query -W -f='${Version}' "$HEADER_PACKAGE" 2>/dev/null) ||
  die "cannot determine the version of $HEADER_PACKAGE"

BASE_VERSION=${KERNEL_RELEASE%%-*}
SOURCE_PACKAGE="linux-source-$BASE_VERSION"
BUILD_PARENT=${BUILD_PARENT:-"$REPO_ROOT/build"}
DIST_DIR="$REPO_ROOT/dist/$KERNEL_RELEASE"

mkdir -p "$BUILD_PARENT" "$DIST_DIR"
WORK_DIR=$(mktemp -d "$BUILD_PARENT/build-$KERNEL_RELEASE.XXXXXXXX")

cleanup() {
  if [[ ${KEEP_BUILD:-0} == 1 ]]; then
    log "keeping build directory: $WORK_DIR"
  else
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT

if [[ -n ${SOURCE_DEB:-} ]]; then
  SOURCE_DEB=$(realpath -- "$SOURCE_DEB")
  [[ -f $SOURCE_DEB ]] || die "SOURCE_DEB does not exist: $SOURCE_DEB"
else
  log "downloading $SOURCE_PACKAGE version $HEADER_VERSION"
  mkdir -p "$WORK_DIR/download"
  (
    cd "$WORK_DIR/download"
    apt-get download "$SOURCE_PACKAGE=$HEADER_VERSION"
  )
  SOURCE_DEB=$(find "$WORK_DIR/download" -maxdepth 1 -type f -name "${SOURCE_PACKAGE}_*.deb" -print -quit)
  [[ -n $SOURCE_DEB ]] || die "apt did not produce a $SOURCE_PACKAGE package"
fi

PACKAGE_VERSION=$(dpkg-deb -f "$SOURCE_DEB" Version)
[[ $PACKAGE_VERSION == "$HEADER_VERSION" ]] ||
  die "source package version $PACKAGE_VERSION does not match headers $HEADER_VERSION"

log "extracting the matching Ubuntu Bluetooth sources"
mkdir -p "$WORK_DIR/package" "$WORK_DIR/source"
dpkg-deb -x "$SOURCE_DEB" "$WORK_DIR/package"

SOURCE_ARCHIVE="$WORK_DIR/package/usr/src/$SOURCE_PACKAGE/$SOURCE_PACKAGE.tar.bz2"
[[ -f $SOURCE_ARCHIVE ]] || die "source archive not found inside package: $SOURCE_ARCHIVE"

tar -xjf "$SOURCE_ARCHIVE" \
  -C "$WORK_DIR/source" \
  --strip-components=1 \
  "$SOURCE_PACKAGE/net/bluetooth"

while IFS= read -r patch_name; do
  [[ -n $patch_name && $patch_name != \#* ]] || continue
  patch_path="$REPO_ROOT/patches/ubuntu-6.17/$patch_name"
  [[ -f $patch_path ]] || die "patch listed in series is missing: $patch_name"
  log "applying $patch_name"
  patch --directory="$WORK_DIR/source" --strip=1 --batch --forward < "$patch_path"
done < "$REPO_ROOT/patches/ubuntu-6.17/series"

log "building bluetooth.ko for $KERNEL_RELEASE"
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
