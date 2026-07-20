: "${SYSROOT:=$HOME/arm64-sysroot}"
TRIPLE=aarch64-alpine-linux-musl

export ARCH=arm64
export LLVM=1
export CROSS_COMPILE=aarch64-linux-gnu-

export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export RANLIB=llvm-ranlib
export STRIP=llvm-strip
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export READELF=llvm-readelf
export HOSTCC=clang
export HOSTCXX=clang++

for d in /usr/lib/ccache/bin /usr/lib/ccache; do
  if [ -d "$d" ]; then
    case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
  fi
done
export PATH

export CC="clang --target=$TRIPLE --sysroot=$SYSROOT -fuse-ld=lld"
export CXX="clang++ --target=$TRIPLE --sysroot=$SYSROOT -fuse-ld=lld"
export CPP="clang -E"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig"
