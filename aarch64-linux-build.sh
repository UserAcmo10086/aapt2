#!/bin/bash
set -e

TARGET_TRIPLE="aarch64-linux-gnu"
BUILD_DIR="build_aarch64_linux"
ZLIB_VERSION="1.3.1"
ZLIB_INSTALL_DIR="/tmp/zlib-aarch64"

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

if [[ -z "${PROTOC_PATH}" ]]; then
    echo "错误: 请设置 PROTOC_PATH 环境变量"
    help
    exit 1
fi

if ! command -v ${TARGET_TRIPLE}-gcc &> /dev/null; then
    echo "错误: 未找到 ${TARGET_TRIPLE}-gcc，请安装 gcc-${TARGET_TRIPLE}"
    exit 1
fi

if [[ -z "${SYSROOT}" ]]; then
    SYSROOT="/usr/${TARGET_TRIPLE}"
fi

if [[ ! -d "${SYSROOT}" ]]; then
    echo "错误: sysroot 目录不存在: ${SYSROOT}"
    exit 1
fi

# ---------- 下载并编译 zlib 静态库（交叉编译） ----------
if [[ ! -f "${ZLIB_INSTALL_DIR}/lib/libz.a" ]]; then
    echo "正在下载 zlib 源码（从 GitHub 镜像）..."
    ZLIB_URL="https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz"
    wget --progress=dot:giga "${ZLIB_URL}" -O zlib.tar.gz || {
        echo "尝试备用源：https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz"
        wget "https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz" -O zlib.tar.gz
    }
    echo "解压 zlib..."
    tar -xzf zlib.tar.gz
    pushd "zlib-${ZLIB_VERSION}"

    echo "配置交叉编译环境..."
    export CC="${TARGET_TRIPLE}-gcc"
    export AR="${TARGET_TRIPLE}-ar"
    export RANLIB="${TARGET_TRIPLE}-ranlib"
    export CFLAGS="--sysroot=${SYSROOT}"

    echo "运行 configure..."
    ./configure --prefix="${ZLIB_INSTALL_DIR}" --static

    echo "编译 zlib（使用 $(nproc) 线程）..."
    make -j$(nproc)

    echo "安装 zlib 到 ${ZLIB_INSTALL_DIR}..."
    make install
    popd
    rm -rf "zlib-${ZLIB_VERSION}" zlib.tar.gz
    echo "zlib 静态库编译完成: ${ZLIB_INSTALL_DIR}/lib/libz.a"
else
    echo "检测到已存在 zlib 静态库，跳过编译"
fi

# ---------- 清理旧构建目录 ----------
rm -rf "${BUILD_DIR}"

# ---------- 切换 CMake 配置文件 ----------
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

# ---------- CMake 配置 ----------
echo "开始 CMake 配置..."
cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME="Linux" \
    -DCMAKE_SYSTEM_PROCESSOR="aarch64" \
    -DCMAKE_C_COMPILER="${TARGET_TRIPLE}-gcc" \
    -DCMAKE_CXX_COMPILER="${TARGET_TRIPLE}-g++" \
    -DCMAKE_SYSROOT="${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT};${ZLIB_INSTALL_DIR}" \
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

# ---------- 编译 aapt2 ----------
echo "开始编译..."
ninja -C "${BUILD_DIR}" aapt2

# ---------- 剥离调试符号 ----------
${TARGET_TRIPLE}-strip --strip-unneeded "${BUILD_DIR}/bin/aapt2"

echo "构建完成！"
echo "可执行文件位置: ${BUILD_DIR}/bin/aapt2"
file "${BUILD_DIR}/bin/aapt2"
