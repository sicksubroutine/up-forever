cmake_minimum_required(VERSION 3.25)

if(NOT DEFINED KIND)
    message(FATAL_ERROR "KIND is required: patch, minor, or major")
endif()

set(_valid_kinds patch minor major)
if(NOT KIND IN_LIST _valid_kinds)
    message(FATAL_ERROR "Unknown bump kind '${KIND}': expected patch, minor, or major")
endif()

if(NOT DEFINED VERSION_FILE)
    get_filename_component(_project_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
    set(VERSION_FILE "${_project_root}/VERSION")
endif()

if(NOT EXISTS "${VERSION_FILE}")
    message(FATAL_ERROR "Version file not found: ${VERSION_FILE}")
endif()

file(READ "${VERSION_FILE}" _current_version)
string(STRIP "${_current_version}" _current_version)

if(NOT _current_version MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
    message(FATAL_ERROR "VERSION must contain exactly MAJOR.MINOR.PATCH; found '${_current_version}'")
endif()

set(_major "${CMAKE_MATCH_1}")
set(_minor "${CMAKE_MATCH_2}")
set(_patch "${CMAKE_MATCH_3}")

if(KIND STREQUAL "major")
    math(EXPR _major "${_major} + 1")
    set(_minor 0)
    set(_patch 0)
elseif(KIND STREQUAL "minor")
    math(EXPR _minor "${_minor} + 1")
    set(_patch 0)
else()
    math(EXPR _patch "${_patch} + 1")
endif()

set(_new_version "${_major}.${_minor}.${_patch}")
file(WRITE "${VERSION_FILE}" "${_new_version}\n")
message(STATUS "Version: ${_current_version} -> ${_new_version}")
