#!/bin/bash
set -e

# 定义目标架构
TARGET_ARCH="aarch64"
TARGET_TRIPLE="aarch64-linux-gnu"

# 帮助信息
help() {
    script_name=$(basename "$0")
    echo "用法: $script_name"
    echo
    echo "环境要求:"
    echo "  - 必须安装 aarch64-linux-gnu 交叉编译工具链"
    echo "  - 必须设置 PROTOC_PATH 环境变量（指向 protoc 可执行文件）"
    echo "  - 可选设置 SYSROOT 环境变量，默认使用 /usr/aarch64-linux-gnu"
    echo
    echo "示例:"
    echo "  PROTOC_PATH=/usr/local/bin/protoc $script_name"
}

# 检查必要环境变量
if [[ -z "${PROTOC_PATH}" ]]; then
    echo "错误: 请设置 PROTOC_PATH 环境变量"
    help
    exit 1
fi

# 检查交叉编译器是否存在
if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
    echo "错误: 未找到 aarch64-linux-gnu-gcc，请安装 gcc-aarch64-linux-gnu"
    exit 1
fi

# 设置 sysroot 路径，默认使用系统工具链的默认 sysroot
if [[ -z "${SYSROOT}" ]]; then
    SYSROOT="/usr/aarch64-linux-gnu"
fi

# 检查 sysroot 是否存在
if [[ ! -d "${SYSROOT}" ]]; then
    echo "错误: sysroot 目录不存在: ${SYSROOT}"
    exit 1
fi

# 配置 CMake 交叉编译参数
cmake -GNinja \
    -B "build_aarch64_linux" \
    -DCMAKE_SYSTEM_NAME="Linux" \
    -DCMAKE_SYSTEM_PROCESSOR="${TARGET_ARCH}" \
    -DCMAKE_C_COMPILER="${TARGET_TRIPLE}-gcc" \
    -DCMAKE_CXX_COMPILER="${TARGET_TRIPLE}-g++" \
    -DCMAKE_SYSROOT="${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM="NEVER" \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY="ONLY" \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE="ONLY" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    -DTHREADS_PREFER_PTHREAD_FLAG=ON \
    -DCMAKE_USE_PTHREADS_INIT=TRUE \
    -DThreads_FOUND=TRUE \
    -DCMAKE_THREAD_LIBS_INIT="-lpthread" \
    -DCMAKE_HAVE_THREADS_LIBRARY=TRUE \
    -C "CMakeLists-aarch64-linux.txt"

# 构建可执行文件
ninja -C build_aarch64_linux aapt2

# 剥离调试符号（可选）
aarch64-linux-gnu-strip --strip-unneeded "build_aarch64_linux/bin/aapt2"

# 输出文件信息
echo "构建完成，可执行文件位于: build_aarch64_linux/bin/aapt2"
file "build_aarch64_linux/bin/aapt2"
