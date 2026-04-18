#!/bin/bash

mkdir -p "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.h" "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.cpp" "submodules/incremental_delivery/sysprop/"

cp "misc/platform_tools_version.h" "submodules/soong/cc/libbuildversion/include"

configPattern="s#frameworks/base/tools/aapt2/Configuration.proto#Configuration.proto#g"
ressourcesPattern="s#frameworks/base/tools/aapt2/Resources.proto#Resources.proto#g"

sed -i "$configPattern" "submodules/base/tools/aapt2/Resources.proto"
sed -i "$configPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

sed -i "$ressourcesPattern" "submodules/base/tools/aapt2/ApkInfo.proto"
sed -i "$ressourcesPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

git apply "patches/apktool_ibotpeaches.patch"
git apply "patches/protobuf.patch"
git apply "patches/32bsystem_on_armv8.patch"

STRINGSTREAM_FILE="submodules/base/tools/aapt2/io/StringStream.cpp"
if [[ -f "$STRINGSTREAM_FILE" ]]; then
    sed -i '/#include "io\/StringStream.h"/a #include <cstring>\n#include <limits>' "$STRINGSTREAM_FILE"
    echo "已修复 StringStream.cpp 缺失的头文件"
fi

ln -sf "submodules/googletest" "submodules/boringssl/src/third_party/googletest"
