#!/bin/bash
set -e

# 定义目标架构
TARGET_TRIPLE="aarch64-linux-gnu"
BUILD_DIR="build_aarch64_linux"

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
if ! command -v ${TARGET_TRIPLE}-gcc &> /dev/null; then
    echo "错误: 未找到 ${TARGET_TRIPLE}-gcc，请安装 gcc-${TARGET_TRIPLE}"
    exit 1
fi

# 设置 sysroot 路径
if [[ -z "${SYSROOT}" ]]; then
    SYSROOT="/usr/${TARGET_TRIPLE}"
fi

if [[ ! -d "${SYSROOT}" ]]; then
    echo "错误: sysroot 目录不存在: ${SYSROOT}"
    exit 1
fi

# 清理之前的构建目录（可选，避免缓存问题）
rm -rf "${BUILD_DIR}"

# 备份原 CMakeLists.txt，使用专用配置
echo "切换到 Linux aarch64 专用 CMake 配置文件..."
mv CMakeLists.txt CMakeLists-android.bak
cp CMakeLists-aarch64-linux.txt CMakeLists.txt

# 确保无论脚本如何退出，都能恢复原 CMakeLists.txt
restore_cmake() {
    if [[ -f CMakeLists-android.bak ]]; then
        echo "恢复原始 CMakeLists.txt 文件..."
        mv CMakeLists-android.bak CMakeLists.txt
    fi
}
trap restore_cmake EXIT

# 配置 CMake（交叉编译 Linux aarch64）
echo "开始 CMake 配置..."
cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME="Linux" \
    -DCMAKE_SYSTEM_PROCESSOR="aarch64" \
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
    -DCMAKE_HAVE_THREADS_LIBRARY=TRUE

# 构建 aapt2
echo "开始编译..."
ninja -C "${BUILD_DIR}" aapt2

# 剥离调试符号（可选，生成更小的可执行文件）
${TARGET_TRIPLE}-strip --strip-unneeded "${BUILD_DIR}/bin/aapt2"

echo "构建完成！"
echo "可执行文件位置: ${BUILD_DIR}/bin/aapt2"
file "${BUILD_DIR}/bin/aapt2"
