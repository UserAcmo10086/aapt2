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

# 工具链路径
TOOLCHAIN="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"
CLANG_VER=$(ls "${TOOLCHAIN}/lib/clang" | head -1)  # 例如 14.0.6
CLANG_LIB_BASE="${TOOLCHAIN}/lib/clang/${CLANG_VER}/lib/linux"

# 查找包含 compiler-rt 静态库的目录（可能没有 aarch64-unknown-linux-gnu 子目录）
# 在 linux 目录下寻找 libclang_rt.builtins-aarch64.a
CRT_LIB_DIR=""
if [[ -f "${CLANG_LIB_BASE}/libclang_rt.builtins-aarch64.a" ]]; then
    CRT_LIB_DIR="${CLANG_LIB_BASE}"
else
    # 尝试查找子目录
    CRT_LIB_DIR=$(find "${CLANG_LIB_BASE}" -type f -name "libclang_rt.builtins-aarch64.a" -printf "%h\n" 2>/dev/null | head -1)
    if [[ -z "${CRT_LIB_DIR}" ]]; then
        echo "错误：在 ${CLANG_LIB_BASE} 下未找到 libclang_rt.builtins-aarch64.a"
        exit 1
    fi
fi

echo ">>> NDK compiler-rt 目录: ${CRT_LIB_DIR}"

# Linux sysroot 由系统的 libc6-dev-arm64-cross 提供（安装后位于 /usr/aarch64-linux-gnu）
LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"
if [[ ! -d "${LINUX_SYSROOT}" ]]; then
    echo "错误：Linux sysroot 目录 ${LINUX_SYSROOT} 不存在，请安装 libc6-dev-arm64-cross。"
    exit 1
fi

# 编译器
CMAKE_C_COMPILER="${TOOLCHAIN}/bin/clang"
CMAKE_CXX_COMPILER="${TOOLCHAIN}/bin/clang++"

# 编译标志：目标 Linux，使用系统 sysroot，启用 compiler-rt 和 libc++
COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT}"
COMMON_FLAGS+=" -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++2a -stdlib=libc++ -rtlib=compiler-rt"

# 链接器标志：完全静态，手动指定启动文件和静态库
START_FILES="${LINUX_SYSROOT}/usr/lib/crt1.o ${LINUX_SYSROOT}/usr/lib/crti.o"
END_FILES="${LINUX_SYSROOT}/usr/lib/crtn.o"

STATIC_LIBS="-l:libc++.a -l:libc++abi.a -l:libunwind.a"
STATIC_LIBS+=" -l:libc.a -l:libm.a -l:libdl.a -l:libpthread.a -l:librt.a"

# 添加 compiler-rt builtins 库
COMPILER_RT_LIB="${CRT_LIB_DIR}/libclang_rt.builtins-aarch64.a"
if [[ -f "${COMPILER_RT_LIB}" ]]; then
    STATIC_LIBS+=" ${COMPILER_RT_LIB}"
else
    echo "警告：未找到 compiler-rt builtins 库，链接可能失败。"
fi

LINKER_FLAGS="-fuse-ld=lld -static -nostdlib"
LINKER_FLAGS+=" -L${LINUX_SYSROOT}/usr/lib -L${LINUX_SYSROOT}/lib"
LINKER_FLAGS+=" -L${CRT_LIB_DIR}"
LINKER_FLAGS+=" ${START_FILES}"
LINKER_FLAGS+=" ${STATIC_LIBS}"
LINKER_FLAGS+=" ${END_FILES}"

# 强制 CMake 识别 pthread
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
