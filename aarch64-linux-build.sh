#!/bin/bash
set -e

# 检查必要的环境变量
if [[ -z "${ANDROID_NDK}" ]]; then
    echo "错误：请设置环境变量 ANDROID_NDK 指向 NDK r25c 根目录。"
    exit 1
fi

if [[ -z "${PROTOC_PATH}" ]]; then
    echo "错误：请设置环境变量 PROTOC_PATH 指向 protoc 可执行文件路径。"
    exit 1
fi

# 构建目录名称
BUILD_DIR="build_aarch64_linux"

# 清理并创建构建目录
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 保存原始 CMakeLists.txt，退出时恢复
ORIG_CMAKE="CMakeLists.txt"
TARGET_CMAKE="CMakeLists-aarch64-linux.txt"

if [[ ! -f "${ORIG_CMAKE}" ]]; then
    echo "错误：${ORIG_CMAKE} 不存在。"
    exit 1
fi

# 临时替换 CMakeLists.txt
mv "${ORIG_CMAKE}" "${ORIG_CMAKE}.bak"
cp "${TARGET_CMAKE}" "${ORIG_CMAKE}"

# 定义恢复函数，确保脚本退出时恢复原始文件
restore_cmake() {
    if [[ -f "${ORIG_CMAKE}.bak" ]]; then
        mv "${ORIG_CMAKE}.bak" "${ORIG_CMAKE}"
    fi
}
trap restore_cmake EXIT

# 配置 CMake 参数
CMAKE_C_COMPILER="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
CMAKE_CXX_COMPILER="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
SYSROOT="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${SYSROOT}"

echo ">>> 开始配置 CMake (目标: Linux aarch64)..."
cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER="${CMAKE_C_COMPILER}" \
    -DCMAKE_CXX_COMPILER="${CMAKE_CXX_COMPILER}" \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS} -fPIC -Wno-attributes -std=gnu11 -fcolor-diagnostics" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS} -fPIC -Wno-attributes -std=gnu++2a -fcolor-diagnostics" \
    -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld -static" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DTHREADS_PREFER_PTHREAD_FLAG=ON \
    -DCMAKE_USE_PTHREADS_INIT=TRUE \
    -DThreads_FOUND=TRUE \
    -DCMAKE_THREAD_LIBS_INIT="-lpthread" \
    -DCMAKE_HAVE_THREADS_LIBRARY=TRUE

echo ">>> 开始编译 aapt2..."
ninja -C "${BUILD_DIR}" aapt2

# 剥离调试符号
LLVM_STRIP="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
if [[ -f "${LLVM_STRIP}" ]]; then
    echo ">>> 剥离符号信息..."
    "${LLVM_STRIP}" --strip-unneeded "${BUILD_DIR}/bin/aapt2"
else
    echo "警告：未找到 llvm-strip，跳过符号剥离。"
fi

echo ">>> 构建完成！可执行文件位于: ${BUILD_DIR}/bin/aapt2"
file "${BUILD_DIR}/bin/aapt2"
