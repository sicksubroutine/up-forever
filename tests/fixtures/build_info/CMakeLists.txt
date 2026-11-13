cmake_minimum_required(VERSION 3.25)
project(provenance VERSION 1.2.3 LANGUAGES CXX)

include("${UP_FOREVER_ROOT}/cmake/UpForever.cmake")

add_library(probe OBJECT probe.cpp)
up_forever_build_info(TARGET probe NAMESPACE provenance OUT "${CMAKE_CURRENT_BINARY_DIR}/build_info.hpp")
