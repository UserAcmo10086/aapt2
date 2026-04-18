#!/bin/bash
# aarch64-linux-build.sh
# 交叉编译 aarch64-linux-gnu 平台的 aapt2 可执行文件
# 依赖：gcc-aarch64-linux-gnu, g++-aarch64-linux-gnu, cmake, ninja-build

set -e

# 设置交叉编译工具链
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++

# 获取工具链的 sysroot（通常包含标准库和头文件）
SYSROOT=$(aarch64-linux-gnu-gcc -print-sysroot)
if [ -z "$SYSROOT" ]; then
    # 若 sysroot 为空，使用 Ubuntu 交叉编译包的默认路径
    SYSROOT="/usr/aarch64-linux-gnu"
fi

BUILD_DIR="build-linux"

# 清理旧的构建目录（可选）
rm -rf "$BUILD_DIR"

# 配置 CMake，使用专用的 CMakeLists-aarch64-linux.txt
cmake -GNinja \
  -B "$BUILD_DIR" \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DCMAKE_C_FLAGS="-fPIC" \
  -DCMAKE_CXX_FLAGS="-fPIC" \
  -DCMAKE_EXE_LINKER_FLAGS="-static" \
  -DPNG_SHARED=OFF \
  -DZLIB_USE_STATIC_LIBS=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY

# 构建 aapt2 目标
ninja -C "$BUILD_DIR" aapt2

# 去除调试符号，减小体积
aarch64-linux-gnu-strip --strip-unneeded "$BUILD_DIR/bin/aapt2"

echo "编译成功：$BUILD_DIR/bin/aapt2"
