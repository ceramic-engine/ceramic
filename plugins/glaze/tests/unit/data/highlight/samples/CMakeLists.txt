cmake_minimum_required(VERSION 3.20)
project(demo LANGUAGES C CXX)
# Sources
set(SOURCES src/main.cpp src/util.cpp)
add_executable(demo ${SOURCES})
target_compile_options(demo PRIVATE -Wall "-O2")
