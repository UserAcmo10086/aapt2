#!/bin/bash
set -e

echo ">>> 应用 Linux aarch64 构建所需的轻量级补丁..."

# 创建必要的目录并复制辅助文件
mkdir -p "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.h" "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.cpp" "submodules/incremental_delivery/sysprop/"

cp "misc/platform_tools_version.h" "submodules/soong/cc/libbuildversion/include"

# 修正 proto 文件中的导入路径
configPattern="s#frameworks/base/tools/aapt2/Configuration.proto#Configuration.proto#g"
resourcesPattern="s#frameworks/base/tools/aapt2/Resources.proto#Resources.proto#g"

sed -i "$configPattern" "submodules/base/tools/aapt2/Resources.proto"
sed -i "$configPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

sed -i "$resourcesPattern" "submodules/base/tools/aapt2/ApkInfo.proto"
sed -i "$resourcesPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

# 应用上游补丁（如果存在）
if [[ -f "patches/apktool_ibotpeaches.patch" ]]; then
    echo ">>> 应用 apktool_ibotpeaches.patch"
    git apply "patches/apktool_ibotpeaches.patch" || echo "警告：补丁应用失败，请手动检查。"
fi

if [[ -f "patches/protobuf.patch" ]]; then
    echo ">>> 应用 protobuf.patch"
    git apply "patches/protobuf.patch" || echo "警告：补丁应用失败，请手动检查。"
fi

if [[ -f "patches/32bsystem_on_armv8.patch" ]]; then
    echo ">>> 应用 32bsystem_on_armv8.patch"
    git apply "patches/32bsystem_on_armv8.patch" || echo "警告：补丁应用失败，请手动检查。"
fi

# 修复 posix_strerror_r.cpp 中的 strerror_r 返回类型问题
TARGET_FILE="submodules/libbase/posix_strerror_r.cpp"
if [[ -f "$TARGET_FILE" ]]; then
    echo ">>> 修复 $TARGET_FILE 的 strerror_r 返回类型"
    # 单行 sed 命令：将 GNU 返回指针转为 int 状态码（成功返回 0，失败返回 -1）
    sed -i 's/return strerror_r(errnum, buf, buflen);/return (int)(strerror_r(errnum, buf, buflen) ? 0 : -1);/' "$TARGET_FILE"
else
    echo "警告：$TARGET_FILE 不存在，跳过修复。"
fi

# 修复 native_handle.cpp：添加 fdsan.h 包含并移除类型转换
NATIVE_HANDLE_FILE="submodules/core/libcutils/native_handle.cpp"
if [[ -f "$NATIVE_HANDLE_FILE" ]]; then
    echo ">>> 修复 $NATIVE_HANDLE_FILE 的 fdsan 头文件包含"
    # 在 #include <cutils/native_handle.h> 之后插入 #include <android/fdsan.h>
    sed -i '/^#include <cutils\/native_handle.h>/a #include <android/fdsan.h>' "$NATIVE_HANDLE_FILE"
    # 将原来带类型转换的调用改回直接使用枚举
    sed -i 's/android_fdsan_create_owner_tag((enum android_fdsan_owner_type)ANDROID_FDSAN_OWNER_TYPE_NATIVE_HANDLE,/android_fdsan_create_owner_tag(ANDROID_FDSAN_OWNER_TYPE_NATIVE_HANDLE,/' "$NATIVE_HANDLE_FILE"
fi

# 创建符号链接
ln -sf "../../googletest" "submodules/boringssl/src/third_party/googletest"

echo ">>> 补丁应用完成。"
