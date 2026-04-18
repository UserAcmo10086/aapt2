#!/bin/bash
set -e

# 检查环境变量
if [[ -z "${ANDROID_NDK}" ]]; then
    echo "错误：请设置环境变量 ANDROID_NDK 指向 NDK r25c 根目录。"
    exit 1
fi

if [[ -z "${PROTOC_PATH}" ]]; then
    echo "错误：请设置环境变量 PROTOC_PATH 指向 protoc 可执行文件路径。"
    exit 1
fi

# 构建目录
BUILD_DIR="build_aarch64_linux"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 临时替换 CMakeLists.txt
mv CMakeLists.txt CMakeLists.txt.bak
cp CMakeLists-aarch64-linux.txt CMakeLists.txt
trap 'mv CMakeLists.txt.bak CMakeLists.txt' EXIT

# 编译器路径
CC="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
CXX="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"

# 两个 sysroot：
# 1. Linux sysroot（提供 glibc、crt 文件）
LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"
# 2. NDK sysroot（提供 Android 头文件，用于源码中 android/log.h 等）
NDK_SYSROOT="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

# 检查必要目录
if [[ ! -d "${LINUX_SYSROOT}" ]]; then
    echo "错误：Linux sysroot 不存在，请安装 gcc-aarch64-linux-gnu libc6-dev-arm64-cross"
    exit 1
fi

# 编译标志：目标 Linux aarch64，主 sysroot 使用 Linux 的，同时添加 NDK sysroot 作为头文件后备
CFLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} -isystem ${NDK_SYSROOT}/usr/include -fPIC -std=gnu11"
CXXFLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} -isystem ${NDK_SYSROOT}/usr/include -fPIC -std=gnu++2a"

# 链接标志：静态链接，使用 lld
LDFLAGS="-fuse-ld=lld -static"
# 添加 Linux sysroot 库目录
LDFLAGS+=" -L${LINUX_SYSROOT}/usr/lib -L${LINUX_SYSROOT}/lib"
# 添加 GCC 库目录（包含 crtbeginT.o 等）
GCC_LIB=$(aarch64-linux-gnu-gcc -print-libgcc-file-name | xargs dirname)
LDFLAGS+=" -L${GCC_LIB}"
# 添加 NDK compiler-rt 库目录，提供内置函数（libclang_rt.builtins-*.a）
CLANG_RES="$(${CC} --print-resource-dir)"
LDFLAGS+=" -L${CLANG_RES}/lib/linux/aarch64"
# 直接链接 builtins 库（使用其原名）
LDFLAGS+=" -l:libclang_rt.builtins-aarch64-android.a"

# 强制 pthread 支持
THREAD_FLAGS=(
    -DTHREADS_PREFER_PTHREAD_FLAG=ON
    -DCMAKE_USE_PTHREADS_INIT=TRUE
    -DThreads_FOUND=TRUE
    -DCMAKE_THREAD_LIBS_INIT="-lpthread"
    -DCMAKE_HAVE_THREADS_LIBRARY=TRUE
)

# 运行 CMake 配置
cmake -GNinja -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    "${THREAD_FLAGS[@]}"

# 编译
ninja -C "${BUILD_DIR}" aapt2

# 剥离符号
LLVM_STRIP="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
if [[ -f "${LLVM_STRIP}" ]]; then
    "${LLVM_STRIP}" --strip-unneeded "${BUILD_DIR}/bin/aapt2"
fi

echo ">>> 构建完成：${BUILD_DIR}/bin/aapt2"
file "${BUILD_DIR}/bin/aapt2"
