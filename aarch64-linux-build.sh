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

NDK_SYSROOT="${TOOLCHAIN}/sysroot"

if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
    echo "错误：未找到 aarch64-linux-gnu-gcc，请安装 gcc-12-aarch64-linux-gnu"
    exit 1
fi
CRTBEGIN_T_DIR=$(aarch64-linux-gnu-gcc -print-file-name=crtbeginT.o | xargs dirname)
[[ ! -d "${CRTBEGIN_T_DIR}" ]] && echo "错误：无法确定 crtbeginT.o 目录" && exit 1
echo ">>> crtbeginT.o 目录: ${CRTBEGIN_T_DIR}"

CXX_BASE="${LINUX_SYSROOT}/include/c++"
[[ ! -d "${CXX_BASE}" ]] && echo "错误：${CXX_BASE} 不存在" && exit 1
CXX_VER=$(find "${CXX_BASE}" -maxdepth 1 -type d -name "[0-9]*" | sort -V | tail -1)
[[ -z "${CXX_VER}" ]] && echo "错误：未找到 C++ 版本目录" && exit 1
CXX_TOP_DIR="${CXX_VER}"
CXX_ARCH_DIR="${CXX_VER}/aarch64-linux-gnu"
[[ ! -d "${CXX_ARCH_DIR}" ]] && echo "错误：${CXX_ARCH_DIR} 不存在" && exit 1
echo ">>> C++ 头文件目录: ${CXX_TOP_DIR}"

ZLIB_LIBRARY="${LINUX_SYSROOT}/lib/libz.a"
[[ ! -f "${ZLIB_LIBRARY}" ]] && echo "错误：未找到 libz.a" && exit 1
ZLIB_INCLUDE_DIR="${LINUX_SYSROOT}/include"
[[ ! -f "${ZLIB_INCLUDE_DIR}/zlib.h" ]] && echo "错误：未找到 zlib.h" && exit 1
echo ">>> ZLIB 库: ${ZLIB_LIBRARY}"

export LIBRARY_PATH="${CRTBEGIN_T_DIR}:${LINUX_SYSROOT}/lib:${LINUX_SYSROOT}/usr/lib:${LIBRARY_PATH}"

COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} --gcc-toolchain=/usr"
COMMON_FLAGS+=" -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++17"
CXXFLAGS+=" -D__GLIBC_PREREQ\(x,y\)=1 -D__GNUC_PREREQ\(x,y\)=1 -D__GLIBC_USE\(x\)=1"
CXXFLAGS+=" -include limits -include cstring"
CXXFLAGS+=" -isystem ${CXX_TOP_DIR} -isystem ${CXX_ARCH_DIR}"

LINKER_FLAGS="-fuse-ld=lld -static -L${CRTBEGIN_T_DIR} -L${LINUX_SYSROOT}/lib -L${LINUX_SYSROOT}/usr/lib -lstdc++"

cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_SYSROOT="${LINUX_SYSROOT}" \
    -DCMAKE_C_COMPILER="${CLANG}" \
    -DCMAKE_CXX_COMPILER="${CLANGXX}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${LINKER_FLAGS}" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_C_COMPILER_WORKS=ON \
    -DCMAKE_CXX_COMPILER_WORKS=ON \
    -DZLIB_LIBRARY="${ZLIB_LIBRARY}" \
    -DZLIB_INCLUDE_DIR="${ZLIB_INCLUDE_DIR}" \
    -DPNG_ARM_NEON=off \
    -DEXTRA_LIB_DIRS="${CRTBEGIN_T_DIR}" \
    -DNDK_SYSROOT="${NDK_SYSROOT}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DTHREADS_PREFER_PTHREAD_FLAG=ON

ninja -C "${BUILD_DIR}" aapt2

[[ -f "${LLVM_STRIP}" ]] && "${LLVM_STRIP}" --strip-unneeded "${BUILD_DIR}/bin/aapt2"
echo ">>> 构建完成！"
file "${BUILD_DIR}/bin/aapt2"
