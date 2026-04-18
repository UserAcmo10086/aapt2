#!/bin/bash
set -e

# 环境变量检查
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

# NDK 工具链
TOOLCHAIN="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="${TOOLCHAIN}/bin/clang"
CLANGXX="${TOOLCHAIN}/bin/clang++"
LLVM_STRIP="${TOOLCHAIN}/bin/llvm-strip"

# Linux sysroot（目标平台根文件系统）
LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"
if [[ ! -d "${LINUX_SYSROOT}" ]]; then
    echo "错误：Linux sysroot ${LINUX_SYSROOT} 不存在，请安装 libc6-dev-arm64-cross"
    exit 1
fi

# 动态查找 libstdc++.a（目标平台 C++ 静态库）
STDCPP_A=$(find "${LINUX_SYSROOT}" -name "libstdc++.a" 2>/dev/null | head -1)
if [[ -z "${STDCPP_A}" ]]; then
    GCC_BASE="/usr/lib/gcc-cross/aarch64-linux-gnu"
    STDCPP_A=$(find "${GCC_BASE}" -name "libstdc++.a" 2>/dev/null | head -1)
fi
if [[ -z "${STDCPP_A}" ]]; then
    echo "错误：未找到 libstdc++.a，请安装 libstdc++-arm64-cross"
    exit 1
fi
STDCPP_DIR=$(dirname "${STDCPP_A}")
echo ">>> libstdc++.a 目录: ${STDCPP_DIR}"

# 动态探测 GCC 版本目录（启动文件）
GCC_BASE="/usr/lib/gcc-cross/aarch64-linux-gnu"
[[ ! -d "${GCC_BASE}" ]] && echo "错误：${GCC_BASE} 不存在，请安装 gcc-aarch64-linux-gnu" && exit 1
GCC_VER_DIR=$(find "${GCC_BASE}" -maxdepth 1 -type d -name "[0-9]*" | sort -V | tail -1)
[[ -z "${GCC_VER_DIR}" ]] && echo "错误：未找到 GCC 版本目录" && exit 1
echo ">>> GCC 版本目录: ${GCC_VER_DIR}"

# 设置库搜索路径环境变量
export LIBRARY_PATH="${STDCPP_DIR}:${GCC_VER_DIR}:${LINUX_SYSROOT}/lib:${LINUX_SYSROOT}/usr/lib:${LIBRARY_PATH}"

# 编译标志
COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} --gcc-toolchain=/usr"
COMMON_FLAGS+=" -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++2a -lstdc++"   # 直接在 CXXFLAGS 中加入 -lstdc++

# 链接器标志
LINKER_FLAGS="-fuse-ld=lld -static -L${STDCPP_DIR} -L${GCC_VER_DIR} -L${LINUX_SYSROOT}/lib -L${LINUX_SYSROOT}/usr/lib"

echo ">>> sysroot: ${LINUX_SYSROOT}"
echo ">>> 开始 CMake 配置（无测试）..."

# 关键：使用 CMake 的交叉编译宏跳过所有测试
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
    -DEXTRA_LIB_DIRS="${STDCPP_DIR};${GCC_VER_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DTHREADS_PREFER_PTHREAD_FLAG=ON

echo ">>> 开始编译 aapt2..."
ninja -C "${BUILD_DIR}" aapt2

[[ -f "${LLVM_STRIP}" ]] && "${LLVM_STRIP}" --strip-unneeded "${BUILD_DIR}/bin/aapt2"
echo ">>> 构建完成！"
file "${BUILD_DIR}/bin/aapt2"
