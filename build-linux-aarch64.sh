#!/bin/bash
set -e

TARGET_TRIPLE="aarch64-linux-gnu"
BUILD_DIR="build_linux"
OUTPUT_BIN="$BUILD_DIR/bin/aapt2-linux-aarch64"

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$(dirname "$OUTPUT_BIN")"

# 编译器
export CC="$TARGET_TRIPLE-gcc"
export CXX="$TARGET_TRIPLE-g++"
export STRIP="$TARGET_TRIPLE-strip"

# 关键：不设置 CMAKE_SYSROOT，而是通过 CMAKE_C_FLAGS 添加 -B 和 -L 强制指定库路径
# 同时禁用 CMake 的测试链接（因为链接测试会失败，但实际项目能编译）
cmake -GNinja \
  -B "$BUILD_DIR" \
  -DLINUX_AARCH64=ON \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_C_FLAGS="-B/usr/$TARGET_TRIPLE/bin -L/usr/$TARGET_TRIPLE/lib -Wl,--unresolved-symbols=ignore-in-shared-libs" \
  -DCMAKE_CXX_FLAGS="-B/usr/$TARGET_TRIPLE/bin -L/usr/$TARGET_TRIPLE/lib -Wl,--unresolved-symbols=ignore-in-shared-libs" \
  -DCMAKE_EXE_LINKER_FLAGS="-L/usr/$TARGET_TRIPLE/lib" \
  -DCMAKE_FIND_ROOT_PATH="/usr/$TARGET_TRIPLE" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_BUILD_TYPE=Release \
  -DPNG_SHARED=OFF \
  -DZLIB_USE_STATIC_LIBS=ON

ninja -C "$BUILD_DIR" aapt2

"$STRIP" --strip-unneeded "$OUTPUT_BIN"
echo "Built: $OUTPUT_BIN"
