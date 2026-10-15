cmake_minimum_required(VERSION 3.25)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" PROJECT_VERSION_VALUE)
string(STRIP "${PROJECT_VERSION_VALUE}" PROJECT_VERSION_VALUE)

if(NOT PROJECT_VERSION_VALUE MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
    message(FATAL_ERROR "VERSION must contain exactly MAJOR.MINOR.PATCH")
endif()

project(
    up_forever
    VERSION "${PROJECT_VERSION_VALUE}"
    DESCRIPTION "Simple Versioning"
    LANGUAGES CXX
)

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(UP_FOREVER_ENABLE_SANITIZERS "Enable AddressSanitizer and UndefinedBehaviorSanitizer" OFF)

add_library(project_options INTERFACE)
target_compile_features(project_options INTERFACE cxx_std_23)

if(MSVC)
    target_compile_options(project_options INTERFACE /W4 /permissive-)
else()
    target_compile_options(
        project_options
        INTERFACE
            -Wall
            -Wextra
            -Wpedantic
            -Werror
            # doctest 2.4.12 uses __COUNTER__, which Clang 23 diagnoses as a C2y extension.
            "$<$<AND:$<COMPILE_LANG_AND_ID:CXX,Clang,AppleClang>,$<BOOL:$<TARGET_PROPERTY:USES_DOCTEST>>>:-Wno-c2y-extensions>"
    )
endif()

if(UP_FOREVER_ENABLE_SANITIZERS)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
        target_compile_options(project_options INTERFACE -fsanitize=address,undefined -fno-omit-frame-pointer)
        target_link_options(project_options INTERFACE -fsanitize=address,undefined -fno-omit-frame-pointer)
    else()
        message(FATAL_ERROR "The sanitizer configuration currently supports Clang and GCC")
    endif()
endif()

set(PROJECT_PUBLIC_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
set(PROJECT_GENERATED_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/include")
file(MAKE_DIRECTORY "${PROJECT_GENERATED_INCLUDE_DIR}/up_forever")
configure_file(
    cmake/version.hpp.in.jinja
    "${PROJECT_GENERATED_INCLUDE_DIR}/up_forever/version.hpp"
    @ONLY
)

add_executable(up-forever src/main.cpp)
target_link_libraries(up-forever PRIVATE project_options)
target_include_directories(
    up-forever
    PRIVATE
        "${PROJECT_PUBLIC_INCLUDE_DIR}"
        "${PROJECT_GENERATED_INCLUDE_DIR}"
)

set_target_properties(
    up-forever
    PROPERTIES
        CXX_EXTENSIONS OFF
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin"
)

include(CTest)

if(BUILD_TESTING)
    include(cmake/HeaderSelfContainment.cmake)
    add_header_self_containment_target(
        header_self_containment
        HEADER_ROOTS
            "${PROJECT_PUBLIC_INCLUDE_DIR}"
            "${PROJECT_GENERATED_INCLUDE_DIR}"
        LINK_LIBRARIES
            project_options
    )

    include(FetchContent)
    FetchContent_Declare(
        doctest
        GIT_REPOSITORY https://github.com/doctest/doctest.git
        GIT_TAG v2.4.12
        GIT_SHALLOW TRUE
    )
    FetchContent_MakeAvailable(doctest)
    include("${doctest_SOURCE_DIR}/scripts/cmake/doctest.cmake")

    foreach(test_target IN ITEMS test_example test_version)
        add_executable("${test_target}" "tests/${test_target}.cpp")
        target_link_libraries("${test_target}" PRIVATE doctest::doctest project_options)
        set_target_properties("${test_target}" PROPERTIES USES_DOCTEST TRUE)
        target_include_directories(
            "${test_target}"
            PRIVATE
                "${PROJECT_PUBLIC_INCLUDE_DIR}"
                "${PROJECT_GENERATED_INCLUDE_DIR}"
        )
        set_target_properties(
            "${test_target}"
            PROPERTIES
                CXX_EXTENSIONS OFF
                RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin"
        )
        doctest_discover_tests("${test_target}")
    endforeach()
endif()
