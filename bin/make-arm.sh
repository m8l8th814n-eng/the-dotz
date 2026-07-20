#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/env-make.sh"

: "${SYSROOT:=$HOME/arm64-sysroot}"
: "${ALPINE_BRANCH:=edge}"
: "${ALPINE_MIRROR:=https://dl-cdn.alpinelinux.org/alpine}"
TRIPLE=aarch64-alpine-linux-musl
JOBS=$(nproc)

ccache_pfx=()
command -v ccache >/dev/null && ccache_pfx=(ccache)
clang_cc=("${ccache_pfx[@]}" clang --target="$TRIPLE" --sysroot="$SYSROOT" -fuse-ld=lld)

apk_static() {
  command -v apk.static >/dev/null || {
    echo "apk.static saknas — installera apk-tools-static (AUR)" >&2; exit 1; }
  apk.static \
    -X "$ALPINE_MIRROR/$ALPINE_BRANCH/main" \
    -X "$ALPINE_MIRROR/$ALPINE_BRANCH/community" \
    --arch aarch64 --root "$SYSROOT" --allow-untrusted "$@"
}

usage() {
  cat >&2 <<EOF
make-arm.sh <cmd>   (SYSROOT=$SYSROOT  branch=$ALPINE_BRANCH)
  sysroot          bootstrap aarch64 Alpine/musl sysroot
  add <pkg...>     apk add packages (t.ex. \`add zlib-dev\`) into sysroot
  kernel <args>    make LLVM=1 ARCH=arm64 <args>   (defconfig, Image, dtbs, ...)
  cc <args>        clang, aarch64-musl + sysroot
  cxx <args>       clang++, samma
  shell            subshell med CC/CXX/AR/pkg-config satta för autotools/meson
EOF
  exit "${1:-1}"
}

cmd=${1:-}; [ $# -gt 0 ] && shift || true
case "$cmd" in
  sysroot)
    mkdir -p "$SYSROOT"
    apk_static -U --initdb add alpine-base musl-dev linux-headers "$@"
    ;;
  add)
    [ $# -gt 0 ] || usage
    apk_static add "$@"
    ;;
  kernel)
    exec make -j"$JOBS" "$@"
    ;;
  cc)  exec "${clang_cc[@]}" "$@" ;;
  cxx) exec "${clang_cc[@]/clang/clang++}" "$@" ;;
  shell)
    export CC="${clang_cc[*]}" CXX="${clang_cc[*]/clang/clang++}"
    export AR=llvm-ar RANLIB=llvm-ranlib NM=llvm-nm STRIP=llvm-strip
    export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
    export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
    exec "${SHELL:-bash}"
    ;;
  ""|-h|--help) usage 0 ;;
  *) usage ;;
esac
