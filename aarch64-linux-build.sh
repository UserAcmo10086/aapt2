
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

# NDK 工具链基础路径
TOOLCHAIN="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"

# 编译器
CMAKE_C_COMPILER="${TOOLCHAIN}/bin/clang"
CMAKE_CXX_COMPILER="${TOOLCHAIN}/bin/clang++"

# NDK 自带的 Linux 目标 sysroot（包含标准 C 头文件和 crt1.o 等）
NDK_LINUX_SYSROOT="${TOOLCHAIN}/sysroot"
# compiler-rt 和 libc++ 静态库路径（Linux aarch64）
NDK_LIB_DIR="${TOOLCHAIN}/lib/clang/14.0.7/lib/linux"
if [[ ! -d "${NDK_LIB_DIR}" ]]; then
    # 兼容不同 NDK 版本
    NDK_LIB_DIR=$(find "${TOOLCHAIN}/lib/clang" -maxdepth 3 -type d -name "aarch64-unknown-linux-gnu" 2>/dev/null | head -1)
    if [[ -z "${NDK_LIB_DIR}" ]]; then
        echo "错误：无法找到 NDK 中的 Linux aarch64 静态库目录。"
        exit 1
    fi
fi

echo ">>> NDK Linux 静态库目录: ${NDK_LIB_DIR}"

# 编译标志：目标为 aarch64-linux-gnu，使用 NDK sysroot
COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${NDK_LINUX_SYSROOT}"
COMMON_FLAGS+=" -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++2a"

# 链接器标志：完全静态，使用 compiler-rt 和 libc++
# -nostdlib 避免自动链接 GCC 库，手动指定启动文件和静态库
START_FILES="${NDK_LIB_DIR}/crt1.o ${NDK_LIB_DIR}/crti.o ${NDK_LIB_DIR}/crtbeginT.o"
END_FILES="${NDK_LIB_DIR}/crtend.o ${NDK_LIB_DIR}/crtn.o"
STATIC_LIBS="-l:libc++.a -l:libc++abi.a -l:libunwind.a -l:libc.a -l:libm.a -l:libdl.a -l:libpthread.a -l:librt.a"

LINKER_FLAGS="-fuse-ld=lld -static -nostdlib"
LINKER_FLAGS+=" -L${NDK_LIB_DIR}"
LINKER_FLAGS+=" ${START_FILES}"
LINKER_FLAGS+=" ${STATIC_LIBS}"
LINKER_FLAGS+=" ${END_FILES}"

# 强制 CMake 使用正确的 pthread 设置
PTHREAD_CFLAGS="-DCMAKE_USE_PTHREADS_INIT=TRUE -DThreads_FOUND=TRUE"
PTHREAD_LDFLAGS="-DCMAKE_THREAD_LIBS_INIT=-lpthread -DCMAKE_HAVE_THREADS_LIBRARY=TRUE"

echo ">>> 开始配置 CMake (目标: Linux aarch64)..."

cmake -GNinja \
    -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER="${CMAKE_C_COMPILER}" \
    -DCMAKE_CXX_COMPILER="${CMAKE_CXX_COMPILER}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${LINKER_FLAGS}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPNG_SHARED=OFF \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DTHREADS_PREFER_PTHREAD_FLAG=ON \
    ${PTHREAD_CFLAGS} \
    ${PTHREAD_LDFLAGS}

echo ">>> 开始编译 aapt2..."
ninja -C "${BUILD_DIR}" aapt2

# 剥离调试符号
LLVM_STRIP="${TOOLCHAIN}/bin/llvm-strip"
if [[ -f "${LLVM_STRIP}" ]]; then
    echo ">>> 剥离符号信息..."
    "${LLVM_STRIP}" --strip-unneeded "${BUILD_DIR}/bin/aapt2"
else
    echo "警告：未找到 llvm-strip，跳过符号剥离。"
fi

echo ">>> 构建完成！可执行文件位于: ${BUILD_DIR}/bin/aapt2"
file "${BUILD_DIR}/bin/aapt2"
