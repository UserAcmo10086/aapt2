#!/bin/bash
set -e

# 使用 GCC 12 版本以避免 ICE
TARGET_TRIPLE="aarch64-linux-gnu"
CC="${TARGET_TRIPLE}-gcc-12"
CXX="${TARGET_TRIPLE}-g++-12"
BUILD_DIR="build_aarch64_linux"
SYSROOT_BASE="/usr/aarch64-linux-gnu"

help() {
    script_name=$(basename "$0")
    echo "用法: $script_name"
    echo
    echo "环境要求:"
    echo "  - 必须安装 gcc-12-aarch64-linux-gnu 和 g++-12-aarch64-linux-gnu"
    echo "  - 必须设置 PROTOC_PATH 环境变量（指向 protoc 可执行文件）"
    echo
    echo "示例:"
    echo "  PROTOC_PATH=/usr/local/bin/protoc $script_name"
}

if [[ -z "${PROTOC_PATH}" ]]; then
    echo "错误: 请设置 PROTOC_PATH 环境变量"
    help
    exit 1
fi

if ! command -v ${CC} &> /dev/null; then
    echo "错误: 未找到 ${CC}，请安装 gcc-12-${TARGET_TRIPLE}"
    exit 1
fi

if ! command -v ${CXX} &> /dev/null; then
    echo "错误: 未找到 ${CXX}，请安装 g++-12-${TARGET_TRIPLE}"
    exit 1
fi

if [[ ! -d "${SYSROOT_BASE}" ]]; then
    echo "错误: 交叉编译根目录不存在: ${SYSROOT_BASE}"
    exit 1
fi

rm -rf "${BUILD_DIR}"

echo "切换到 Linux aarch64 专用 CMake 配置文件..."
mv CMakeLists.txt CMakeLists-android.bak
cp CMakeLists-aarch64-linux.txt CMakeLists.txt

restore_cmake() {
    if [[ -f CMakeLists-android.bak ]]; then
        echo "恢复原始 CMakeLists.txt 文件..."
        mv CMakeLists-android.bak CMakeLists.txt
    fi
}
trap restore_cmake EXIT

echo "开始 CMake 配置..."
cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME="Linux" \
    -DCMAKE_SYSTEM_PROCESSOR="aarch64" \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DCMAKE_C_FLAGS="-I${SYSROOT_BASE}/include" \
    -DCMAKE_CXX_FLAGS="-I${SYSROOT_BASE}/include" \
    -DCMAKE_EXE_LINKER_FLAGS="-L${SYSROOT_BASE}/lib -static" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DTHREADS_PREFER_PTHREAD_FLAG=ON \
    -DCMAKE_USE_PTHREADS_INIT=TRUE \
    -DThreads_FOUND=TRUE \
    -DCMAKE_THREAD_LIBS_INIT="-lpthread" \
    -DCMAKE_HAVE_THREADS_LIBRARY=TRUE

echo "开始编译..."
ninja -C "${BUILD_DIR}" aapt2

# 使用 GCC 12 对应的 strip
${TARGET_TRIPLE}-strip --strip-unneeded "${BUILD_DIR}/bin/aapt2"

echo "构建完成！"
echo "可执行文件位置: ${BUILD_DIR}/bin/aapt2"
file "${BUILD_DIR}/bin/aapt2"
