#!/bin/bash
set -e

TARGET_TRIPLE="aarch64-linux-gnu"
BUILD_DIR="build_linux"
OUTPUT_BIN="$BUILD_DIR/bin/aapt2-linux-aarch64"

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$(dirname "$OUTPUT_BIN")"

# 使用工具链文件进行配置
cmake -GNinja \
  -B "$BUILD_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="aarch64-linux-gnu.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DPNG_SHARED=OFF \
  -DZLIB_USE_STATIC_LIBS=ON

# 编译
ninja -C "$BUILD_DIR" aapt2

# 去除调试符号
aarch64-linux-gnu-strip --strip-unneeded "$OUTPUT_BIN"
echo "Built: $OUTPUT_BIN"
