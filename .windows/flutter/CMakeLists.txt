cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "immy_app")
project(${PROJECT_NAME} LANGUAGES CXX)

set(BINARY_NAME ${PROJECT_NAME})
enable_language(C)
enable_language(CXX)

# Enable developer mode for symlink support
add_definitions(-D_DEVELOPER_MODE)

# Flutter configuration
include(flutter/generated_plugins.cmake)
