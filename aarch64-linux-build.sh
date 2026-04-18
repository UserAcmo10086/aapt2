#!/bin/bash
set -e

# 定义目标架构（仅 aarch64 Linux）
TARGET_ARCH="aarch64"
TARGET_TRIPLET="aarch64-linux-gnu"

# 显示帮助信息
help() {
    script_name=$(basename "$0")
    echo "用法: $script_name"
    echo
    echo "环境变量要求:"
    echo "  - PROTOC_PATH: 必须设置为 protoc 可执行文件路径（可选，若未设置则尝试使用系统 protoc）"
    echo "  - SYSROOT: 可选，指定交叉编译的 sysroot 路径（默认使用工具链自带）"
    echo "  - CROSS_COMPILE: 可选，指定交叉编译前缀（默认 aarch64-linux-gnu-）"
    echo
    echo "示例:"
    echo "  PROTOC_PATH=/usr/local/bin/protoc ./aarch64-linux-build.sh"
}

# 检查 protoc 是否可用
if [[ -z "${PROTOC_PATH}" ]]; then
    if command -v protoc &> /dev/null; then
        PROTOC_PATH=$(command -v protoc)
        echo "使用系统 protoc: $PROTOC_PATH"
    else
        echo "错误: 未找到 protoc，请设置 PROTOC_PATH 环境变量或将其安装到系统。"
        help
        exit 1
    fi
fi

# 设置交叉编译工具链前缀
if [[ -z "${CROSS_COMPILE}" ]]; then
    CROSS_COMPILE="${TARGET_TRIPLET}-"
fi

# 检查交叉编译器是否存在
if ! command -v "${CROSS_COMPILE}gcc" &> /dev/null; then
    echo "错误: 未找到交叉编译器 ${CROSS_COMPILE}gcc。"
    exit 1
fi

# === 关键修改：使用专用的 Linux CMakeLists 文件 ===
if [[ -f "CMakeLists-aarch64-linux.txt" ]]; then
    echo "备份原 CMakeLists.txt 并使用 Linux 专用版本..."
    if [[ -f "CMakeLists.txt" ]] && [[ ! -f "CMakeLists.txt.bak" ]]; then
        mv CMakeLists.txt CMakeLists.txt.bak
    fi
    cp CMakeLists-aarch64-linux.txt CMakeLists.txt
else
    echo "警告: CMakeLists-aarch64-linux.txt 不存在，将使用现有 CMakeLists.txt（可能不兼容）"
fi

# 可选 sysroot
if [[ -n "${SYSROOT}" ]]; then
    SYSROOT_CMAKE_ARG="-DCMAKE_SYSROOT=${SYSROOT}"
else
    SYSROOT_CMAKE_ARG=""
fi

# 创建构建目录
BUILD_DIR="build-linux-aarch64"
mkdir -p "${BUILD_DIR}"

echo "配置 CMake 进行 aarch64 Linux 交叉编译..."

cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_C_COMPILER="${CROSS_COMPILE}gcc" \
    -DCMAKE_CXX_COMPILER="${CROSS_COMPILE}g++" \
    -DCMAKE_ASM_COMPILER="${CROSS_COMPILE}as" \
    -DCMAKE_SYSTEM_NAME="Linux" \
    -DCMAKE_SYSTEM_PROCESSOR="${TARGET_ARCH}" \
    ${SYSROOT_CMAKE_ARG} \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM="NEVER" \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY="ONLY" \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE="ONLY" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE="ONLY" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DPROTOC_PATH="${PROTOC_PATH}" \
    -DTARGET_ARCH="${TARGET_ARCH}"

echo "开始构建 aapt2..."
ninja -C "${BUILD_DIR}" aapt2

OUTPUT_BIN="${BUILD_DIR}/bin/aapt2"
if [[ -f "${OUTPUT_BIN}" ]]; then
    "${CROSS_COMPILE}strip" --strip-unneeded "${OUTPUT_BIN}"
    echo "构建成功: ${OUTPUT_BIN}"
    file "${OUTPUT_BIN}"
else
    echo "构建失败：未找到生成的可执行文件"
    exit 1
fi
