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

# Linux AArch64 交叉编译 sysroot（由 libc6-dev-arm64-cross 提供）
LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"

if [[ ! -d "${LINUX_SYSROOT}" ]]; then
    echo "错误：Linux sysroot 目录 ${LINUX_SYSROOT} 不存在，请安装 gcc-aarch64-linux-gnu 和 libc6-dev-arm64-cross。"
    exit 1
fi

# 使用 NDK 自带的 compiler-rt 和 libunwind，避免依赖 GCC 运行时
# 添加 compiler-rt 库路径（位于 NDK 中）
NDK_CLANG_RESOURCE_DIR="$("${CMAKE_C_COMPILER}" --print-resource-dir)"
COMPILER_RT_LIB="${NDK_CLANG_RESOURCE_DIR}/lib/linux"

echo ">>> compiler-rt 库路径: ${COMPILER_RT_LIB}"

# 基础编译标志：目标三元组 + sysroot + 使用 compiler-rt
COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT}"
COMMON_FLAGS+=" -rtlib=compiler-rt -unwindlib=libunwind"

# 静态链接标志：链接器使用 lld，静态链接，并指定库搜索路径
LINKER_FLAGS="-fuse-ld=lld -static"
LINKER_FLAGS+=" -L${LINUX_SYSROOT}/usr/lib -L${LINUX_SYSROOT}/lib"
LINKER_FLAGS+=" -L${COMPILER_RT_LIB}"
# 显式链接 compiler-rt 内置函数
LINKER_FLAGS+=" -l:libclang_rt.builtins-aarch64.a"

# 添加 GCC 库目录以备不时之需（如果存在）
if command -v aarch64-linux-gnu-gcc &> /dev/null; then
    GCC_LIB_DIR=$(aarch64-linux-gnu-gcc -print-libgcc-file-name | xargs dirname)
    echo ">>> 备用 GCC 库目录: ${GCC_LIB_DIR}"
    LINKER_FLAGS+=" -L${GCC_LIB_DIR}"
fi

echo ">>> 使用的 sysroot: ${LINUX_SYSROOT}"
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
