cmake_minimum_required(VERSION 3.14.2)
project(build-tools)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)

# 区分 Android 与 Linux 构建
if(DEFINED ANDROID_ABI)
    set(BUILD_FOR_ANDROID TRUE)
    if(ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "armeabi-v7a")
        enable_language(ASM)
    elseif(ANDROID_ABI STREQUAL "x86_64" OR ANDROID_ABI STREQUAL "x86")
        enable_language(ASM_NASM)
    else()
        message(FATAL_ERROR "Unsupported Android architecture: ${ANDROID_ABI}")
    endif()
elseif(LINUX_AARCH64)
    set(BUILD_FOR_LINUX TRUE)
    # Linux aarch64 使用 GNU as
    enable_language(ASM)
else()
    message(FATAL_ERROR "Please set either ANDROID_ABI or LINUX_AARCH64=ON")
endif()

# 通用编译标志
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fcolor-diagnostics -fPIC -Wno-attributes -std=gnu11")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fcolor-diagnostics -fPIC -Wno-attributes -std=gnu++2a")

# 链接标志：Android 必须静态链接，Linux 可选（这里保持静态，但需确保静态库存在）
if(BUILD_FOR_ANDROID)
    set(CMAKE_EXE_LINKER_FLAGS "-static")
else()
    # Linux 静态链接（若工具链缺少静态库，可改为动态或注释）
    set(CMAKE_EXE_LINKER_FLAGS "-static")
endif()

# 平台版本（仅影响版本字符串，Linux 下可给一个默认值）
if(BUILD_FOR_ANDROID)
    set(TOOLS_VERSION 35.0.2)
else()
    set(TOOLS_VERSION "linux-35.0.2")
endif()

# 源码路径
set(SRC ${PROJECT_SOURCE_DIR}/submodules)

# 64-bit off_t
add_definitions(-D_FILE_OFFSET_BITS=64)

# protobuf 配置
set(protobuf_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(protobuf_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(protobuf_BUILD_PROTOC_BINARIES OFF CACHE BOOL "" FORCE)
set(protobuf_BUILD_LIBPROTOC ON CACHE BOOL "" FORCE)

# 第三方库
add_subdirectory(submodules/boringssl EXCLUDE_FROM_ALL)
add_subdirectory(submodules/fmtlib EXCLUDE_FROM_ALL)
add_subdirectory(submodules/pcre EXCLUDE_FROM_ALL)
add_subdirectory(submodules/libpng EXCLUDE_FROM_ALL)
add_subdirectory(submodules/jsoncpp EXCLUDE_FROM_ALL)
add_subdirectory(submodules/expat/expat EXCLUDE_FROM_ALL)
add_subdirectory(submodules/protobuf EXCLUDE_FROM_ALL)
add_subdirectory(submodules/googletest EXCLUDE_FROM_ALL)

# 主构建逻辑（cmake/ 目录下的 CMakeLists.txt 也需要支持 Linux）
add_subdirectory(cmake)
