#!/bin/bash
set -e

# 目标架构
TARGET_TRIPLE="aarch64-linux-gnu"
BUILD_DIR="build_linux"
OUTPUT_BIN="$BUILD_DIR/bin/aapt2-linux-aarch64"

# 清理旧构建
rm -rf "$BUILD_DIR"
mkdir -p "$(dirname "$OUTPUT_BIN")"

# 设置交叉编译工具链
export CC="$TARGET_TRIPLE-gcc"
export CXX="$TARGET_TRIPLE-g++"
export AR="$TARGET_TRIPLE-ar"
export STRIP="$TARGET_TRIPLE-strip"

# 配置 CMake（注意传递 -DLINUX_AARCH64=ON）
cmake -GNinja \
  -B "$BUILD_DIR" \
  -DLINUX_AARCH64=ON \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_FIND_ROOT_PATH="/usr/$TARGET_TRIPLE" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_BUILD_TYPE=Release \
  -DPNG_SHARED=OFF \
  -DZLIB_USE_STATIC_LIBS=ON

# 编译
ninja -C "$BUILD_DIR" aapt2

# 去除调试符号
"$STRIP" --strip-unneeded "$OUTPUT_BIN"

echo "Built: $OUTPUT_BIN"
