#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/env-make.sh"

CROSS="${MESON_CROSS:-$SYSROOT/aarch64-musl.ini}"
mkdir -p "$SYSROOT"

cat > "$CROSS" <<EOF
[binaries]
c = ['clang', '--target=$TRIPLE', '--sysroot=$SYSROOT']
cpp = ['clang++', '--target=$TRIPLE', '--sysroot=$SYSROOT']
c_ld = 'lld'
cpp_ld = 'lld'
ar = 'llvm-ar'
nm = 'llvm-nm'
strip = 'llvm-strip'
ranlib = 'llvm-ranlib'
objcopy = 'llvm-objcopy'
pkgconfig = 'pkg-config'
exe_wrapper = ['qemu-aarch64-static', '-L', '$SYSROOT']

[host_machine]
system = 'linux'
kernel = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[properties]
sys_root = '$SYSROOT'
pkg_config_libdir = '$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig'
EOF

unset CC CXX CPP LD AR NM RANLIB STRIP OBJCOPY OBJDUMP READELF \
  HOSTCC HOSTCXX CROSS_COMPILE ARCH LLVM \
  PKG_CONFIG_SYSROOT_DIR PKG_CONFIG_LIBDIR

exec meson "$@" --cross-file "$CROSS"
