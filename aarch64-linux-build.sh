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

mv "${ORIG_CMAKE}" "${ORIG_CMAKE}.bak"
cp "${TARGET_CMAKE}" "${ORIG_CMAKE}"

restore_cmake() {
    if [[ -f "${ORIG_CMAKE}.bak" ]]; then
        mv "${ORIG_CMAKE}.bak" "${ORIG_CMAKE}"
    fi
}
trap restore_cmake EXIT

# 配置编译器路径
CMAKE_C_COMPILER="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
CMAKE_CXX_COMPILER="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"

# Linux AArch64 交叉编译 sysroot（由 gcc-aarch64-linux-gnu/libc6-dev-arm64-cross 提供）
# 若未安装，可在 GitHub Actions 中通过 apt 安装，或手动指定路径。
LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"

if [[ ! -d "${LINUX_SYSROOT}" ]]; then
    echo "警告：Linux sysroot 目录 ${LINUX_SYSROOT} 不存在，尝试使用 NDK sysroot 但可能缺少 GNU 库文件。"
    # 降级使用 NDK sysroot，并补充库路径（可能仍会失败）
    SYSROOT="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
    EXTRA_LDFLAGS="-L${SYSROOT}/usr/lib/aarch64-linux-gnu -L${SYSROOT}/usr/lib"
else
    SYSROOT="${LINUX_SYSROOT}"
    EXTRA_LDFLAGS=""
fi

COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${SYSROOT}"
# 强制静态链接，并指定 crt 文件路径（确保链接器能找到 crt1.o 等）
LINKER_FLAGS="-fuse-ld=lld -static -L${SYSROOT}/usr/lib -L${SYSROOT}/lib"

echo ">>> 使用的 sysroot: ${SYSROOT}"
echo ">>> 开始配置 CMake (目标: Linux aarch64)..."

cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER="${CMAKE_C_COMPILER}" \
    -DCMAKE_CXX_COMPILER="${CMAKE_CXX_COMPILER}" \
    -DCMAKE_C_FLAGS="${COMMON_FLAGS} -fPIC -Wno-attributes -std=gnu11 -fcolor-diagnostics" \
    -DCMAKE_CXX_FLAGS="${COMMON_FLAGS} -fPIC -Wno-attributes -std=gnu++2a -fcolor-diagnostics" \
    -DCMAKE_EXE_LINKER_FLAGS="${LINKER_FLAGS}" \
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
