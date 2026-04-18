#!/bin/bash
set -e

# ============================================================================
# 脚本名称: aarch64-linux-build.sh
# 功能: 使用 Linaro aarch64-linux-gnu 工具链交叉编译 aapt2（Linux 平台静态可执行文件）
# 要求环境变量:
#   TOOLCHAIN_DIR - Linaro 工具链根目录（例如 /path/to/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu）
#   PROTOC_PATH   - protoc 可执行文件的绝对路径（主机 x86_64 版本）
# ============================================================================

# 目标架构与三元组
TARGET_ARCH="aarch64"
TARGET_TRIPLET="aarch64-linux-gnu"

# 显示帮助信息
help() {
    script_name=$(basename "$0")
    echo "用法: $script_name"
    echo
    echo "必需环境变量:"
    echo "  TOOLCHAIN_DIR   Linaro aarch64-linux-gnu 工具链根目录"
    echo "  PROTOC_PATH     protoc 可执行文件路径（主机版本）"
    echo
    echo "示例:"
    echo "  export TOOLCHAIN_DIR=/opt/toolchain"
    echo "  export PROTOC_PATH=/usr/local/bin/protoc"
    echo "  ./$script_name"
}

# 检查 TOOLCHAIN_DIR 环境变量
if [[ -z "${TOOLCHAIN_DIR}" ]]; then
    echo "错误: 环境变量 TOOLCHAIN_DIR 未设置。"
    help
    exit 1
fi

# 检查 TOOLCHAIN_DIR 是否存在
if [[ ! -d "${TOOLCHAIN_DIR}" ]]; then
    echo "错误: TOOLCHAIN_DIR 指向的目录不存在: ${TOOLCHAIN_DIR}"
    exit 1
fi

# 检查 PROTOC_PATH 环境变量
if [[ -z "${PROTOC_PATH}" ]]; then
    # 如果未设置，尝试在 PATH 中寻找
    if command -v protoc &> /dev/null; then
        PROTOC_PATH=$(command -v protoc)
        echo "未设置 PROTOC_PATH，使用系统 protoc: $PROTOC_PATH"
    else
        echo "错误: 未设置 PROTOC_PATH，且系统中未找到 protoc。"
        help
        exit 1
    fi
fi

# 验证 protoc 是否可执行
if [[ ! -x "${PROTOC_PATH}" ]]; then
    echo "错误: PROTOC_PATH 指向的文件不可执行: ${PROTOC_PATH}"
    exit 1
fi

# 输出使用的环境变量
echo "=========================================="
echo "交叉编译配置信息:"
echo "  TOOLCHAIN_DIR: ${TOOLCHAIN_DIR}"
echo "  PROTOC_PATH:   ${PROTOC_PATH}"
echo "=========================================="

# 替换 CMakeLists.txt 为 Linux 专用版本
if [[ -f "CMakeLists-aarch64-linux.txt" ]]; then
    echo "使用专用的 Linux CMakeLists 文件..."
    # 备份原文件（如果存在且未备份过）
    if [[ -f "CMakeLists.txt" ]] && [[ ! -f "CMakeLists.txt.bak" ]]; then
        mv CMakeLists.txt CMakeLists.txt.bak
        echo "原 CMakeLists.txt 已备份为 CMakeLists.txt.bak"
    fi
    cp CMakeLists-aarch64-linux.txt CMakeLists.txt
else
    echo "警告: CMakeLists-aarch64-linux.txt 不存在，将使用当前目录的 CMakeLists.txt（可能不兼容）"
fi

# 定义工具链中各工具的完整路径
TOOLCHAIN_BIN="${TOOLCHAIN_DIR}/bin"
SYSROOT="${TOOLCHAIN_DIR}/${TARGET_TRIPLET}/libc"

# 设置交叉编译器及相关工具
export CC="${TOOLCHAIN_BIN}/${TARGET_TRIPLET}-gcc"
export CXX="${TOOLCHAIN_BIN}/${TARGET_TRIPLET}-g++"
export AR="${TOOLCHAIN_BIN}/${TARGET_TRIPLET}-ar"
export AS="${TOOLCHAIN_BIN}/${TARGET_TRIPLET}-as"
export RANLIB="${TOOLCHAIN_BIN}/${TARGET_TRIPLET}-ranlib"
export STRIP="${TOOLCHAIN_BIN}/${TARGET_TRIPLET}-strip"

# 验证编译器是否存在
if [[ ! -x "${CC}" ]]; then
    echo "错误: C 编译器不存在或不可执行: ${CC}"
    exit 1
fi
if [[ ! -x "${CXX}" ]]; then
    echo "错误: C++ 编译器不存在或不可执行: ${CXX}"
    exit 1
fi

echo "使用的编译器:"
echo "  CC:  ${CC}"
echo "  CXX: ${CXX}"

# 编译标志：静态链接，生成位置无关代码
CFLAGS="-static -fPIC"
CXXFLAGS="-static -fPIC"
# 链接标志：静态链接，显式链接 pthread
LDFLAGS="-static -pthread"

export CFLAGS
export CXXFLAGS
export LDFLAGS

# 创建构建目录
BUILD_DIR="build-linux-aarch64"
mkdir -p "${BUILD_DIR}"

echo "=========================================="
echo "开始 CMake 配置..."
echo "构建目录: ${BUILD_DIR}"
echo "Sysroot:   ${SYSROOT}"
echo "=========================================="

# 运行 CMake 配置（Ninja 生成器）
cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DCMAKE_AR="${AR}" \
    -DCMAKE_ASM_COMPILER="${AS}" \
    -DCMAKE_RANLIB="${RANLIB}" \
    -DCMAKE_STRIP="${STRIP}" \
    -DCMAKE_SYSTEM_NAME="Linux" \
    -DCMAKE_SYSTEM_PROCESSOR="${TARGET_ARCH}" \
    -DCMAKE_SYSROOT="${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH="${SYSROOT}" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM="NEVER" \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY="ONLY" \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE="ONLY" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE="ONLY" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DPROTOC_PATH="${PROTOC_PATH}" \
    -DTARGET_ARCH="${TARGET_ARCH}"

echo "=========================================="
echo "开始构建 aapt2 目标..."
echo "=========================================="

# 执行构建
ninja -C "${BUILD_DIR}" aapt2

# 检查生成的可执行文件
OUTPUT_BIN="${BUILD_DIR}/bin/aapt2"
if [[ -f "${OUTPUT_BIN}" ]]; then
    echo "构建成功，正在 strip 调试符号..."
    "${STRIP}" --strip-unneeded "${OUTPUT_BIN}"
    echo "=========================================="
    echo "最终可执行文件: ${OUTPUT_BIN}"
    echo "文件类型信息:"
    file "${OUTPUT_BIN}"
    echo "=========================================="
else
    echo "错误: 构建失败，未生成可执行文件 ${OUTPUT_BIN}"
    exit 1
fi
