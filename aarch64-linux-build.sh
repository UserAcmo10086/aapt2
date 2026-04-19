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

# 使用 aarch64-linux-gnu-gcc 定位 crtbeginT.o 目录（仅用于获取路径）
if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
    echo "错误：未找到 aarch64-linux-gnu-gcc，请安装 gcc-aarch64-linux-gnu"
    exit 1
fi
CRTBEGIN_T_DIR=$(aarch64-linux-gnu-gcc -print-file-name=crtbeginT.o | xargs dirname)
[[ ! -d "${CRTBEGIN_T_DIR}" ]] && echo "错误：无法确定 crtbeginT.o 目录" && exit 1
echo ">>> crtbeginT.o 目录: ${CRTBEGIN_T_DIR}"

# 动态定位 C++ 头文件目录：查找 c++config.h
CXX_CONFIG_H=$(find "${LINUX_SYSROOT}/include/c++" -name "c++config.h" 2>/dev/null | head -1)
if [[ -z "${CXX_CONFIG_H}" ]]; then
    echo "错误：未找到 c++config.h，请安装 libstdc++-arm64-cross"
    exit 1
fi
# 路径示例: /usr/aarch64-linux-gnu/include/c++/13/aarch64-linux-gnu/bits/c++config.h
CXX_BASE_DIR=$(echo "${CXX_CONFIG_H}" | sed 's|/aarch64-linux-gnu/bits/c++config.h||')
CXX_AARCH64_DIR="${CXX_BASE_DIR}/aarch64-linux-gnu"
if [[ ! -d "${CXX_BASE_DIR}" ]]; then
    echo "错误：无法确定 C++ 基本头文件目录"
    exit 1
fi
echo ">>> C++ 头文件基本目录: ${CXX_BASE_DIR}"
echo ">>> C++ 头文件 aarch64 子目录: ${CXX_AARCH64_DIR}"

# ZLIB 配置
ZLIB_LIBRARY="${LINUX_SYSROOT}/lib/libz.a"
if [[ ! -f "${ZLIB_LIBRARY}" ]]; then
    echo "错误：未找到目标平台的 libz.a，请在工作流中安装 zlib1g-dev:arm64"
    exit 1
fi
ZLIB_INCLUDE_DIR="${LINUX_SYSROOT}/include"
if [[ ! -f "${ZLIB_INCLUDE_DIR}/zlib.h" ]]; then
    echo "错误：未找到目标平台的 zlib.h，请确认安装"
    exit 1
fi
echo ">>> ZLIB 库: ${ZLIB_LIBRARY}"
echo ">>> ZLIB 头文件: ${ZLIB_INCLUDE_DIR}"

export LIBRARY_PATH="${CRTBEGIN_T_DIR}:${LINUX_SYSROOT}/lib:${LINUX_SYSROOT}/usr/lib:${LIBRARY_PATH}"

COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} --gcc-toolchain=/usr"
COMMON_FLAGS+=" -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++2a"
# 添加 C++ 头文件搜索路径
CXXFLAGS+=" -isystem ${CXX_BASE_DIR} -isystem ${CXX_AARCH64_DIR}"

# 链接器标志：静态链接，显式链接 libstdc++
LINKER_FLAGS="-fuse-ld=lld -static -L${CRTBEGIN_T_DIR} -L${LINUX_SYSROOT}/lib -L${LINUX_SYSROOT}/usr/lib -lstdc++"

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
    -DZLIB_LIBRARY="${ZLIB_LIBRARY}" \
    -DZLIB_INCLUDE_DIR="${ZLIB_INCLUDE_DIR}" \
    -DEXTRA_LIB_DIRS="${CRTBEGIN_T_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DTHREADS_PREFER_PTHREAD_FLAG=ON

ninja -C "${BUILD_DIR}" aapt2

[[ -f "${LLVM_STRIP}" ]] && "${LLVM_STRIP}" --strip-unneeded "${BUILD_DIR}/bin/aapt2"
echo ">>> 构建完成！"
file "${BUILD_DIR}/bin/aapt2"
