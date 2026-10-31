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
    LANGUAGES NONE
)

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")

include("${CMAKE_CURRENT_LIST_DIR}/cmake/UpForever.cmake")

# A FetchContent consumer runs this file inside its own build and only wants the function
# above. Anything defined past here (targets, doctest) would land in the consumer too.
if(NOT PROJECT_IS_TOP_LEVEL)
    return()
endif()

enable_language(CXX)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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

option(UP_FOREVER_ENABLE_SANITIZERS "Build the tests with AddressSanitizer and UndefinedBehaviorSanitizer" OFF)
if(UP_FOREVER_ENABLE_SANITIZERS)
    # MSVC has ASan but no UBSan; stopping beats a sanitize run that quietly checks half of what it says.
    if(MSVC)
        message(FATAL_ERROR "UP_FOREVER_ENABLE_SANITIZERS needs GCC or Clang (MSVC has no UndefinedBehaviorSanitizer)")
    endif()
    set(sanitizer_flags -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
    target_compile_options(project_options INTERFACE ${sanitizer_flags})
    target_link_options(project_options INTERFACE ${sanitizer_flags})
endif()

# up-forever eats its own cooking: its header comes from the same function consumers call.
set(PROJECT_GENERATED_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/include")
up_forever_header(NAMESPACE up_forever OUT "${PROJECT_GENERATED_INCLUDE_DIR}/up_forever/version.hpp")

include(CTest)

if(BUILD_TESTING)
    include(FetchContent)
    FetchContent_Declare(
        doctest
        GIT_REPOSITORY https://github.com/doctest/doctest.git
        GIT_TAG v2.5.3
        GIT_SHALLOW TRUE
    )
    FetchContent_MakeAvailable(doctest)
    include("${doctest_SOURCE_DIR}/scripts/cmake/doctest.cmake")

    foreach(test_target IN ITEMS test_version test_build_info)
        add_executable("${test_target}" "tests/${test_target}.cpp")
        target_link_libraries("${test_target}" PRIVATE doctest::doctest project_options)
        target_include_directories("${test_target}" PRIVATE "${PROJECT_GENERATED_INCLUDE_DIR}")
        set_target_properties(
            "${test_target}"
            PROPERTIES
                USES_DOCTEST TRUE
                CXX_EXTENSIONS OFF
                RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/bin"
        )
        doctest_discover_tests("${test_target}")
    endforeach()
    up_forever_build_info(
        TARGET test_build_info
        NAMESPACE up_forever
        OUT "${PROJECT_GENERATED_INCLUDE_DIR}/up_forever/build_info.hpp"
    )

    # The Python module, with the names derived from project() and with both overridden. -B: a cached
    # .pyc would outlive a regenerated version.py when the size and the second match.
    find_package(Python3 3.12 COMPONENTS Interpreter QUIET) # the template's `type` aliases need 3.12
    if(Python3_FOUND)
        set(python_dir "${CMAKE_CURRENT_BINARY_DIR}/generated/python")
        up_forever_python(OUT "${python_dir}/derived/version.py")
        up_forever_python(OUT "${python_dir}/overridden/version.py" PACKAGE pyforever MODULE forever_core)
        add_test(
            NAME "up_forever_python: names from project()"
            COMMAND "${Python3_EXECUTABLE}" -I -B "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_version_py.py" "${python_dir}/derived/version.py"
                    "${PROJECT_VERSION}" up-forever up_forever UP_FOREVER_ENV up_forever
        )
        add_test(
            NAME "up_forever_python: PACKAGE and MODULE override them"
            COMMAND "${Python3_EXECUTABLE}" -I -B "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_version_py.py" "${python_dir}/overridden/version.py"
                    "${PROJECT_VERSION}" pyforever forever_core FOREVER_CORE_ENV up_forever
        )
    else()
        message(STATUS "up-forever: no Python 3.12+, so the up_forever_python tests are skipped")
    endif()
endif()
