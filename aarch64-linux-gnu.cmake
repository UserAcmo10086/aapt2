# 目标系统名称，这里我们明确是 Linux
set(CMAKE_SYSTEM_NAME Linux)
# 目标处理器架构
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 指定交叉编译器
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

# 这一步是关键：告诉 CMake 在哪里寻找目标系统的头文件和库文件
set(CMAKE_SYSROOT /usr/aarch64-linux-gnu)

# 配置 CMake 如何查找库和头文件
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
