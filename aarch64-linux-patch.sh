#!/bin/bash

set -e

# 创建所需目录并复制辅助文件
mkdir -p "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.h" "submodules/incremental_delivery/sysprop/include/"
cp "misc/IncrementalProperties.sysprop.cpp" "submodules/incremental_delivery/sysprop/"

cp "misc/platform_tools_version.h" "submodules/soong/cc/libbuildversion/include"

# 修复 proto 文件中的导入路径
configPattern="s#frameworks/base/tools/aapt2/Configuration.proto#Configuration.proto#g"
ressourcesPattern="s#frameworks/base/tools/aapt2/Resources.proto#Resources.proto#g"

sed -i "$configPattern" "submodules/base/tools/aapt2/Resources.proto"
sed -i "$configPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

sed -i "$ressourcesPattern" "submodules/base/tools/aapt2/ApkInfo.proto"
sed -i "$ressourcesPattern" "submodules/base/tools/aapt2/ResourcesInternal.proto"

# 应用原有补丁
git apply "patches/apktool_ibotpeaches.patch" || true
git apply "patches/protobuf.patch" || true
git apply "patches/32bsystem_on_armv8.patch" || true

# ===== 修复 StringStream.cpp 缺失的头文件 =====
STRINGSTREAM_FILE="submodules/base/tools/aapt2/io/StringStream.cpp"
if [[ -f "$STRINGSTREAM_FILE" ]]; then
    sed -i '/#include "io\/StringStream.h"/a #include <cstring>\n#include <limits>' "$STRINGSTREAM_FILE"
    echo "已修复 StringStream.cpp 缺失的头文件"
fi

# ===== 精确修复 ResourceTable.cpp 中的泛型 lambda =====
RESOURCETABLE_FILE="submodules/base/tools/aapt2/ResourceTable.cpp"
if [[ -f "$RESOURCETABLE_FILE" ]]; then
    # 单行精确替换（源码中只有这一处调用）
    sed -i 's/auto it = std::lower_bound(el.begin(), el.end(), value, \[&\](auto& lhs, auto& rhs) { return Comparer::operator()(lhs, rhs); });/auto it = std::lower_bound(el.begin(), el.end(), value, Comparer());/' "$RESOURCETABLE_FILE"
    echo "已修复 ResourceTable.cpp 的 lambda"
fi

# ===== 修复 logging.cpp 中的 __builtin_available 错误 =====
LOGGING_FILE="submodules/libbase/logging.cpp"
if [[ -f "$LOGGING_FILE" ]]; then
    # 将 __builtin_available(android 30, *) 替换为 false
    sed -i 's/__builtin_available(android [0-9]*, \*)/false/g' "$LOGGING_FILE"
    echo "已修复 logging.cpp 中的 __builtin_available"
fi

# 创建 googletest 符号链接
ln -sf "submodules/googletest" "submodules/boringssl/src/third_party/googletest"
