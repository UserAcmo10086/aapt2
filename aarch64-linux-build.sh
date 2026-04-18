#!/bin/bash
set -e

# 检查环境变量
[[ -z "${ANDROID_NDK}" ]] && echo "错误：请设置 ANDROID_NDK" && exit 1
[[ -z "${PROTOC_PATH}" ]] && echo "错误：请设置 PROTOC_PATH" && exit 1

BUILD_DIR="build_aarch64_linux"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 备份并替换 CMakeLists
ORIG_CMAKE="CMakeLists.txt"
TARGET_CMAKE="CMakeLists-aarch64-linux.txt"
[[ ! -f "${ORIG_CMAKE}" ]] && echo "错误：${ORIG_CMAKE} 不存在" && exit 1
mv "${ORIG_CMAKE}" "${ORIG_CMAKE}.bak"
cp "${TARGET_CMAKE}" "${ORIG_CMAKE}"
trap '[[ -f "${ORIG_CMAKE}.bak" ]] && mv "${ORIG_CMAKE}.bak" "${ORIG_CMAKE}"' EXIT

# NDK 工具链路径
TOOLCHAIN="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="${TOOLCHAIN}/bin/clang"
CLANGXX="${TOOLCHAIN}/bin/clang++"
LLVM_STRIP="${TOOLCHAIN}/bin/llvm-strip"

# Linux sysroot（由 libc6-dev-arm64-cross 提供）
LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"
if [[ ! -d "${LINUX_SYSROOT}" ]]; then
    echo "错误：Linux sysroot ${LINUX_SYSROOT} 不存在，请安装 gcc-aarch64-linux-gnu 和 libc6-dev-arm64-cross"
    exit 1
fi

# 查找 compiler-rt builtins 库（必须位于 lib/linux 子目录，排除 baremetal）
COMPILER_RT_LIB=$(find "${TOOLCHAIN}" -path "*/lib/linux/libclang_rt.builtins-aarch64.a" 2>/dev/null | head -1)
if [[ -z "${COMPILER_RT_LIB}" ]]; then
    echo "错误：未找到 libclang_rt.builtins-aarch64.a (期望在 lib/linux 子目录)"
    exit 1
fi
COMPILER_RT_DIR=$(dirname "${COMPILER_RT_LIB}")
echo ">>> compiler-rt 目录: ${COMPILER_RT_DIR}"

# 编译标志：目标 aarch64-linux-gnu，使用 Linux sysroot
COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++2a"

# 链接器标志：完全静态，强制使用 compiler-rt 和 libstdc++
LINKER_FLAGS="-fuse-ld=lld -static -rtlib=compiler-rt -stdlib=libstdc++ -unwindlib=libunwind"
LINKER_FLAGS+=" -L${COMPILER_RT_DIR}"

echo ">>> sysroot: ${LINUX_SYSROOT}"
echo ">>> 开始 CMake 配置..."

cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER="${CLANG}" \
    -DCMAKE_CXX_COMPILER="${CLANGXX}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
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

if [[ -f "${LLVM_STRIP}" ]]; then
    echo ">>> 剥离符号..."
    "${LLVM_STRIP}" --strip-unneeded "${BUILD_DIR}/bin/aapt2"
fi

echo ">>> 构建完成！"
file "${BUILD_DIR}/bin/aapt2"
