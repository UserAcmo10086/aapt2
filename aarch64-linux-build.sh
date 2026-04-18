#!/bin/bash
set -e

[[ -z "${ANDROID_NDK}" ]] && echo "错误：请设置 ANDROID_NDK" && exit 1
[[ -z "${PROTOC_PATH}" ]] && echo "错误：请设置 PROTOC_PATH" && exit 1

BUILD_DIR="build_aarch64_linux"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

ORIG_CMAKE="CMakeLists.txt"
TARGET_CMAKE="CMakeLists-aarch64-linux.txt"
[[ ! -f "${ORIG_CMAKE}" ]] && echo "错误：${ORIG_CMAKE} 不存在" && exit 1
mv "${ORIG_CMAKE}" "${ORIG_CMAKE}.bak"
cp "${TARGET_CMAKE}" "${ORIG_CMAKE}"
trap '[[ -f "${ORIG_CMAKE}.bak" ]] && mv "${ORIG_CMAKE}.bak" "${ORIG_CMAKE}"' EXIT

TOOLCHAIN="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="${TOOLCHAIN}/bin/clang"
CLANGXX="${TOOLCHAIN}/bin/clang++"
LLVM_STRIP="${TOOLCHAIN}/bin/llvm-strip"

LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"
[[ ! -d "${LINUX_SYSROOT}" ]] && echo "错误：Linux sysroot ${LINUX_SYSROOT} 不存在" && exit 1

# 使用 aarch64-linux-gnu-gcc 定位 libstdc++.a 和 GCC 库目录
if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
    echo "错误：未找到 aarch64-linux-gnu-gcc，请安装 gcc-aarch64-linux-gnu"
    exit 1
fi

GCC_LIB_DIR=$(aarch64-linux-gnu-gcc -print-file-name=libstdc++.a | xargs dirname)
if [[ ! -d "${GCC_LIB_DIR}" ]]; then
    echo "错误：无法确定 libstdc++.a 所在目录"
    exit 1
fi
echo ">>> libstdc++.a 目录: ${GCC_LIB_DIR}"

CRTBEGIN_T_DIR=$(aarch64-linux-gnu-gcc -print-file-name=crtbeginT.o | xargs dirname)
if [[ ! -d "${CRTBEGIN_T_DIR}" ]]; then
    echo "错误：无法确定 crtbeginT.o 所在目录"
    exit 1
fi
echo ">>> crtbeginT.o 目录: ${CRTBEGIN_T_DIR}"

# 库搜索路径
export LIBRARY_PATH="${GCC_LIB_DIR}:${CRTBEGIN_T_DIR}:${LINUX_SYSROOT}/lib:${LINUX_SYSROOT}/usr/lib:${LIBRARY_PATH}"

COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} --gcc-toolchain=/usr"
COMMON_FLAGS+=" -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++2a -lstdc++"

LINKER_FLAGS="-fuse-ld=lld -static -L${GCC_LIB_DIR} -L${CRTBEGIN_T_DIR} -L${LINUX_SYSROOT}/lib -L${LINUX_SYSROOT}/usr/lib"

cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER="${CLANG}" \
    -DCMAKE_CXX_COMPILER="${CLANGXX}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${LINKER_FLAGS}" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_C_COMPILER_WORKS=ON \
    -DCMAKE_CXX_COMPILER_WORKS=ON \
    -DEXTRA_LIB_DIRS="${GCC_LIB_DIR};${CRTBEGIN_T_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DTHREADS_PREFER_PTHREAD_FLAG=ON

ninja -C "${BUILD_DIR}" aapt2

[[ -f "${LLVM_STRIP}" ]] && "${LLVM_STRIP}" --strip-unneeded "${BUILD_DIR}/bin/aapt2"
echo ">>> 构建完成！"
file "${BUILD_DIR}/bin/aapt2"
