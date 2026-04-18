#!/bin/bash
set -e

echo ">>> 应用 Linux aarch64 构建所需的轻量级补丁..."

# 创建必要的目录并复制辅助文件
mkdir -p "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.h" "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.cpp" "submodules/incremental_delivery/sysprop/"

cp "misc/platform_tools_version.h" "submodules/soong/cc/libbuildversion/include"

# 修正 proto 文件中的导入路径（移除 frameworks/base/tools/aapt2/ 前缀）
configPattern="s#frameworks/base/tools/aapt2/Configuration.proto#Configuration.proto#g"
resourcesPattern="s#frameworks/base/tools/aapt2/Resources.proto#Resources.proto#g"

sed -i "$configPattern" "submodules/base/tools/aapt2/Resources.proto"
sed -i "$configPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

sed -i "$resourcesPattern" "submodules/base/tools/aapt2/ApkInfo.proto"
sed -i "$resourcesPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

# 可选应用上游补丁（如果补丁文件存在）
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

# 创建符号链接（与原始 patch.sh 保持一致）
ln -sf "../../googletest" "submodules/boringssl/src/third_party/googletest"

echo ">>> 补丁应用完成。"
