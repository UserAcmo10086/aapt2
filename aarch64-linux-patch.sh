#!/bin/bash
set -e

echo "应用 aarch64 Linux 编译所需的补丁和准备工作..."

# 创建必要的目录并复制头文件（与 Android 版相同）
mkdir -p "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.h" "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.cpp" "submodules/incremental_delivery/sysprop/"

cp "misc/platform_tools_version.h" "submodules/soong/cc/libbuildversion/include"

# 修复 proto 文件中的 include 路径（与 Android 版相同）
configPattern="s#frameworks/base/tools/aapt2/Configuration.proto#Configuration.proto#g"
resourcesPattern="s#frameworks/base/tools/aapt2/Resources.proto#Resources.proto#g"

sed -i "$configPattern" "submodules/base/tools/aapt2/Resources.proto"
sed -i "$configPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

sed -i "$resourcesPattern" "submodules/base/tools/aapt2/ApkInfo.proto"
sed -i "$resourcesPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

# 应用平台相关的补丁
# 1. protobuf.patch：解决 protobuf 构建兼容性问题，与平台无关，应当保留
echo "应用 protobuf.patch..."
if [[ -f "patches/protobuf.patch" ]]; then
    git apply "patches/protobuf.patch"
else
    echo "警告: patches/protobuf.patch 不存在，跳过。"
fi

# 2. apktool_ibotpeaches.patch：针对 apktool 的修改，在 Linux 平台上仍然可能需要（取决于使用场景）
echo "应用 apktool_ibotpeaches.patch..."
if [[ -f "patches/apktool_ibotpeaches.patch" ]]; then
    git apply "patches/apktool_ibotpeaches.patch"
else
    echo "警告: patches/apktool_ibotpeaches.patch 不存在，跳过。"
fi

# 3. 32bsystem_on_armv8.patch：该补丁用于解决在 ARMv8 兼容模式下运行 32 位二进制时的 BusError，
#    由于我们编译的是 64 位 aarch64 二进制，此补丁不需要，跳过
echo "跳过 32bsystem_on_armv8.patch（目标为 64 位 aarch64）"

# 创建符号链接供 boringssl 使用
ln -sf "submodules/googletest" "submodules/boringssl/src/third_party/googletest"

echo "补丁应用完成。"
