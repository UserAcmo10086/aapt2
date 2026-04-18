#!/bin/bash
set -e

# 检查环境变量
[[ -z "${ANDROID_NDK}" ]] && echo "错误：请设置 ANDROID_NDK" && exit 1
[[ -z "${PROTOC_PATH}" ]] && echo "错误：请设置 PROTOC_PATH" && exit 1

BUILD_DIR="build_aarch64_linux"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 备份 CMakeLists
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

# 系统 Linux AArch64 sysroot（提供 crt1.o、libc.a 等）
LINUX_SYSROOT="${LINUX_SYSROOT:-/usr/aarch64-linux-gnu}"
if [[ ! -d "${LINUX_SYSROOT}" ]]; then
    echo "错误：Linux sysroot ${LINUX_SYSROOT} 不存在"
    exit 1
fi

# 动态查找 compiler-rt 内置库（libclang_rt.builtins-aarch64.a）
# 优先在 lib/clang 下查找，再尝试 lib64/clang
COMPILER_RT_LIB=""
for base in "${TOOLCHAIN}/lib/clang" "${TOOLCHAIN}/lib64/clang"; do
    if [[ -d "${base}" ]]; then
        # 查找路径应为 .../lib/linux/libclang_rt.builtins-aarch64.a
        FOUND=$(find "${base}" -type f -path "*/lib/linux/libclang_rt.builtins-aarch64.a" 2>/dev/null | head -1)
        if [[ -n "${FOUND}" ]]; then
            COMPILER_RT_LIB=$(dirname "${FOUND}")
            break
        fi
    fi
done

if [[ -z "${COMPILER_RT_LIB}" ]]; then
    echo "错误：未找到 compiler-rt 内置库 (libclang_rt.builtins-aarch64.a)"
    exit 1
fi
echo ">>> compiler-rt 目录: ${COMPILER_RT_LIB}"

# 编译标志：目标 aarch64-linux-gnu，使用 Linux sysroot
COMMON_FLAGS="--target=aarch64-linux-gnu --sysroot=${LINUX_SYSROOT} -fPIC -Wno-attributes -fcolor-diagnostics"
CFLAGS="${COMMON_FLAGS} -std=gnu11"
CXXFLAGS="${COMMON_FLAGS} -std=gnu++2a"

# 启动文件路径（位于 Linux sysroot 内）
CRT1="${LINUX_SYSROOT}/usr/lib/crt1.o"
CRTI="${LINUX_SYSROOT}/usr/lib/crti.o"
CRTBEGIN_T="${LINUX_SYSROOT}/usr/lib/crtbeginT.o"
CRTEND="${LINUX_SYSROOT}/usr/lib/crtend.o"
CRTN="${LINUX_SYSROOT}/usr/lib/crtn.o"

# 检查必要文件是否存在
for f in "${CRT1}" "${CRTI}" "${CRTBEGIN_T}" "${CRTEND}" "${CRTN}"; do
    if [[ ! -f "${f}" ]]; then
        echo "错误：缺少启动文件 ${f}"
        exit 1
    fi
done

# 链接器标志：完全静态，使用 -nostdlib 并手动指定所有组件
LINKER_FLAGS="-fuse-ld=lld -static -nostdlib"
LINKER_FLAGS+=" ${CRT1} ${CRTI} ${CRTBEGIN_T}"
LINKER_FLAGS+=" -L${LINUX_SYSROOT}/usr/lib -L${LINUX_SYSROOT}/lib"
LINKER_FLAGS+=" -L${COMPILER_RT_LIB}"
LINKER_FLAGS+=" -l:libc.a -l:libm.a -l:libdl.a -l:libpthread.a -l:librt.a"
LINKER_FLAGS+=" -l:libclang_rt.builtins-aarch64.a"
LINKER_FLAGS+=" ${CRTEND} ${CRTN}"

echo ">>> 使用的 sysroot: ${LINUX_SYSROOT}"
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
