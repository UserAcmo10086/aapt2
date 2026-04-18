#!/bin/bash

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
git apply "patches/apktool_ibotpeaches.patch"
git apply "patches/protobuf.patch"
git apply "patches/32bsystem_on_armv8.patch"

# ===== 修复 StringStream.cpp 缺失的头文件 =====
STRINGSTREAM_FILE="submodules/base/tools/aapt2/io/StringStream.cpp"
if [[ -f "$STRINGSTREAM_FILE" ]]; then
    sed -i '/#include "io\/StringStream.h"/a #include <cstring>\n#include <limits>' "$STRINGSTREAM_FILE"
    echo "已修复 StringStream.cpp 缺失的头文件"
fi

# ===== 使用 Perl 精确修复 ResourceTable.cpp 中的泛型 lambda ICE =====
RESOURCETABLE_FILE="submodules/base/tools/aapt2/ResourceTable.cpp"
if [[ -f "$RESOURCETABLE_FILE" ]]; then
    # 多行替换：将带有泛型 lambda 的 std::lower_bound 调用替换为直接使用 Comparer()
    perl -i -0pe 's|auto it = std::lower_bound\(el\.begin\(\), el\.end\(\), value, \[&\](auto& lhs, auto& rhs) \{\s+return Comparer::operator\(\)\(lhs, rhs\);\s+\}\);|auto it = std::lower_bound(el.begin(), el.end(), value, Comparer());|gs' "$RESOURCETABLE_FILE"
    echo "已修复 ResourceTable.cpp 的泛型 lambda 问题"
fi

# 创建 googletest 符号链接
ln -sf "submodules/googletest" "submodules/boringssl/src/third_party/googletest"
