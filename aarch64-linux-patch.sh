#!/bin/bash
# aarch64-linux-patch.sh
# 应用必要的源码补丁，使 aapt2 能够适应 Linux 环境（与原 patch.sh 基本相同）
# 注意：若某些 Android 特有的依赖导致编译失败，可能需要进一步调整，此处保留原始补丁流程

# 复制 Android 增量属性相关文件（Linux 下可能不需要，但保留以通过编译）
mkdir -p "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.h" "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.cpp" "submodules/incremental_delivery/sysprop/"

# 复制平台工具版本头文件
cp "misc/platform_tools_version.h" "submodules/soong/cc/libbuildversion/include"

# 修改 proto 文件的包含路径（将绝对路径改为相对路径）
configPattern="s#frameworks/base/tools/aapt2/Configuration.proto#Configuration.proto#g"
ressourcesPattern="s#frameworks/base/tools/aapt2/Resources.proto#Resources.proto#g"

sed -i "$configPattern" "submodules/base/tools/aapt2/Resources.proto"
sed -i "$configPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

sed -i "$ressourcesPattern" "submodules/base/tools/aapt2/ApkInfo.proto"
sed -i "$ressourcesPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

# 应用第三方补丁（来自 apktool、protobuf 等）
git apply "patches/apktool_ibotpeaches.patch"
git apply "patches/protobuf.patch"
git apply "patches/32bsystem_on_armv8.patch"

# 创建符号链接，供 boringssl 使用 googletest
ln -sf "submodules/googletest" "submodules/boringssl/src/third_party/googletest"
