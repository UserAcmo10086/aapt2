#!/bin/bash
set -e

# ============================================================================
# 脚本名称: aarch64-linux-patch.sh
# 功能: 应用 aapt2 编译所需的补丁和准备工作
# 说明: 复制必要的头文件、修正 proto 文件路径、应用补丁（除 32 位兼容补丁外）
# ============================================================================

echo "=========================================="
echo "开始应用补丁和准备工作..."
echo "=========================================="

# 1. 创建目录并复制 sysprop 相关文件
echo "复制 IncrementalProperties 相关文件..."
mkdir -p "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.h" "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.cpp" "submodules/incremental_delivery/sysprop/"

# 2. 复制 platform_tools_version.h
echo "复制 platform_tools_version.h..."
cp "misc/platform_tools_version.h" "submodules/soong/cc/libbuildversion/include"

# 3. 修正 proto 文件中的 import 路径
echo "修正 proto 文件中的 import 路径..."
configPattern="s#frameworks/base/tools/aapt2/Configuration.proto#Configuration.proto#g"
resourcesPattern="s#frameworks/base/tools/aapt2/Resources.proto#Resources.proto#g"

sed -i "$configPattern" "submodules/base/tools/aapt2/Resources.proto"
sed -i "$configPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

sed -i "$resourcesPattern" "submodules/base/tools/aapt2/ApkInfo.proto"
sed -i "$resourcesPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

# 4. 应用补丁文件（如果存在）
# 注意: 跳过 32bsystem_on_armv8.patch，因为目标是纯 64 位 aarch64
echo "应用 protobuf.patch（如果存在）..."
if [[ -f "patches/protobuf.patch" ]]; then
    git apply "patches/protobuf.patch" || echo "警告: protobuf.patch 应用失败，继续执行..."
else
    echo "patches/protobuf.patch 不存在，跳过。"
fi

echo "应用 apktool_ibotpeaches.patch（如果存在）..."
if [[ -f "patches/apktool_ibotpeaches.patch" ]]; then
    git apply "patches/apktool_ibotpeaches.patch" || echo "警告: apktool_ibotpeaches.patch 应用失败，继续执行..."
else
    echo "patches/apktool_ibotpeaches.patch 不存在，跳过。"
fi

echo "跳过 32bsystem_on_armv8.patch（目标为 64 位 aarch64）。"

# 5. 创建符号链接供 boringssl 使用
echo "创建 googletest 符号链接..."
ln -sf "submodules/googletest" "submodules/boringssl/src/third_party/googletest"

echo "=========================================="
echo "补丁和准备工作完成。"
echo "=========================================="
