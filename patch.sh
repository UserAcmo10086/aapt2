#!/bin/bash
set -e

# 检测是否为 Android 构建（通过环境变量 ANDROID_NDK 或传入参数）
if [[ -n "$ANDROID_NDK" ]]; then
    echo "Applying Android-specific patches..."
    
    mkdir -p "submodules/incremental_delivery/sysprop/include/"
    cp "misc/IncrementalProperties.sysprop.h" "submodules/incremental_delivery/sysprop/include/"
    cp "misc/IncrementalProperties.sysprop.cpp" "submodules/incremental_delivery/sysprop/"
    
    cp "misc/platform_tools_version.h" "submodules/soong/cc/libbuildversion/include"
    
    # 修改 proto 包含路径
    configPattern="s#frameworks/base/tools/aapt2/Configuration.proto#Configuration.proto#g"
    ressourcesPattern="s#frameworks/base/tools/aapt2/Resources.proto#Resources.proto#g"
    
    sed -i "$configPattern" "submodules/base/tools/aapt2/Resources.proto"
    sed -i "$configPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"
    
    sed -i "$ressourcesPattern" "submodules/base/tools/aapt2/ApkInfo.proto"
    sed -i "$ressourcesPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"
    
    # 应用 Git 补丁（这些补丁可能与 Linux 也兼容，但为了安全仅 Android 应用）
    git apply "patches/apktool_ibotpeaches.patch"
    git apply "patches/protobuf.patch"
    
    # Fix BusError
    git apply "patches/32bsystem_on_armv8.patch"
    
    # 软链接 googletest
    ln -sf "submodules/googletest" "submodules/boringssl/src/third_party/googletest"
    
else
    echo "Linux build detected, skipping Android-specific patches."
    # 对于 Linux 构建，可能需要额外的补丁，可在此添加
    # 例如修复 Linux 下的 protobuf 包含路径等
fi
