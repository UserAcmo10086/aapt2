
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

# NDK 工具链
TOOLCHAIN="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="${TOOLCHAIN}/bin/clang"
CLANGXX="${TOOLCHAIN}/bin/clang++"
LLVM_STRIP="${TOOLCHAIN}/bin/llvm-strip"

# Linux sysroot（由 libc6-dev-arm64-cross 提供）
LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"
if [[ ! -d "${LINUX_SYSROOT}" ]]; then
    echo "错误：Linux sysroot ${LINUX_SYSROOT} 不存在"
    exit 1
fi

# 动态查找 crt1.o, crti.o, crtn.o（位于 sysroot 内）
find_file() {
    local name=$1
    local path
    path=$(find "${LINUX_SYSROOT}" -name "${name}" -type f 2>/dev/null | head -1)
    if [[ -z "${path}" ]]; then
        echo "错误：在 ${LINUX_SYSROOT} 中未找到 ${name}"
        exit 1
    fi
    echo "${path}"
}

CRT1=$(find_file "crt1.o")
CRTI=$(find_file "crti.o")
CRTN=$(find_file "crtn.o")

# GCC 交叉编译库目录（提供 crtbeginT.o、crtend.o、libgcc.a 等）
if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
    echo "错误：未找到 aarch64-linux-gnu-gcc，请安装 gcc-aarch64-linux-gnu"
    exit 1
fi
GCC_LIB_DIR=$(aarch64-linux-gnu-gcc -print-file-name=crtbeginT.o | xargs dirname)
if [[ ! -d "${GCC_LIB_DIR}" ]]; then
    echo "错误：无法确定 GCC 库目录"
    exit 1
fi
echo ">>> GCC 库目录: ${GCC_LIB_DIR}"

CRTBEGIN_T="${GCC_LIB_DIR}/crtbeginT.o"
CRTEND="${GCC_LIB_DIR}/crtend.o"
if [[ ! -f "${CRTBEGIN_T}" ]] || [[ ! -f "${CRTEND}" ]]; then
    echo "错误：GCC 目录缺少 crtbeginT.o 或 crtend.o"
    exit 1
fi

# 编译标志：目标 aarch64-linux-gnu，使用 Linux sysroot
COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++2a"

# 链接器标志：完全静态，手动指定启动文件和库
LINKER_FLAGS="-fuse-ld=lld -static -nostdlib"
LINKER_FLAGS+=" ${CRT1} ${CRTI} ${CRTBEGIN_T}"
LINKER_FLAGS+=" -L${LINUX_SYSROOT}/lib -L${LINUX_SYSROOT}/usr/lib"
LINKER_FLAGS+=" -L${GCC_LIB_DIR}"
LINKER_FLAGS+=" -lc -lm -ldl -lpthread -lrt"
LINKER_FLAGS+=" -lgcc -lgcc_eh"          # 使用系统的 libgcc 提供内置函数
LINKER_FLAGS+=" ${CRTEND} ${CRTN}"

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
