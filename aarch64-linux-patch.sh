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

# ===== 使用 Perl 精确替换 ResourceTable.cpp 中的泛型 lambda =====
RESOURCETABLE_FILE="submodules/base/tools/aapt2/ResourceTable.cpp"
if [[ -f "$RESOURCETABLE_FILE" ]]; then
    # 该替换将匹配所有形如：
    #   auto it = std::lower_bound(el.begin(), el.end(), value, [&](auto& lhs, auto& rhs) {
    #       return Comparer::operator()(lhs, rhs);
    #   });
    # 并替换为：
    #   auto it = std::lower_bound(el.begin(), el.end(), value, Comparer());
    perl -0777 -pi -e 's|auto\s+it\s*=\s*std::lower_bound\s*\(\s*el\.begin\s*\(\s*\)\s*,\s*el\.end\s*\(\s*\)\s*,\s*value\s*,\s*\[&\s*\]\s*\(\s*auto\s*&\s*lhs\s*,\s*auto\s*&\s*rhs\s*\)\s*\{\s*return\s+Comparer::operator\s*\(\s*\)\s*\(\s*lhs\s*,\s*rhs\s*\)\s*;\s*\}\s*\)\s*;|auto it = std::lower_bound(el.begin(), el.end(), value, Comparer());|gs' "$RESOURCETABLE_FILE"
    echo "已修复 ResourceTable.cpp 中的泛型 lambda"
fi

# 创建 googletest 符号链接
ln -sf "submodules/googletest" "submodules/boringssl/src/third_party/googletest"
