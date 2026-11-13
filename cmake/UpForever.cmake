include_guard(GLOBAL)

# Container builds often leave .git out of the context, so whoever runs the build (and knows the
# commit) can say it here. Inside a checkout git still decides, and these must agree with it, so a
# stale cache entry can't relabel a build.
set(UP_FOREVER_GIT_SHA "" CACHE STRING
    "Commit for up_forever_build_info() when the source tree isn't a git checkout (12+ hex digits)")
set(UP_FOREVER_GIT_DIRTY "" CACHE STRING
    "ON or OFF: whether that tree had uncommitted changes (required with UP_FOREVER_GIT_SHA)")

function(_up_forever_require_version caller)
    if(NOT PROJECT_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
        message(FATAL_ERROR "${caller}: project(${PROJECT_NAME}) needs VERSION MAJOR.MINOR.PATCH, got '${PROJECT_VERSION}'")
    endif()
endfunction()

# up_forever_header(NAMESPACE <ns> OUT <file>)
#
# Writes the flat Version header for the calling project: name and version come from its
# project(), the namespace from NAMESPACE.
#
#   up_forever_header(NAMESPACE ezu OUT "${CMAKE_CURRENT_BINARY_DIR}/generated/include/ezu/version.hpp")
function(up_forever_header)
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "NAMESPACE;OUT" "")
    if(NOT arg_NAMESPACE OR NOT arg_OUT)
        message(FATAL_ERROR "up_forever_header: NAMESPACE and OUT are required")
    endif()
    _up_forever_require_version(up_forever_header)

    set(VERSION_NAMESPACE "${arg_NAMESPACE}")
    # The function's own directory, not the caller's: that's what lets any consumer call it.
    configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../up_forever/version.hpp.in" "${arg_OUT}" @ONLY)
endfunction()

# up_forever_python(OUT <file> [PACKAGE <name>] [MODULE <name>])
#
# Writes the Python version module for the calling project, the same facts as version.hpp. Python
# has two names: PACKAGE is what pip installs (bear-config), MODULE what code imports
# (bear_config). Both default to project()'s name with _ and - swapped to fit, so project(bear_config)
# and project(bear-config) give the same pair; the env variable is MODULE in capitals plus _ENV.
#
#   up_forever_python(OUT "${CMAKE_CURRENT_SOURCE_DIR}/src/my_app/version.py")
function(up_forever_python)
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "OUT;PACKAGE;MODULE" "")
    if(NOT arg_OUT)
        message(FATAL_ERROR "up_forever_python: OUT is required")
    endif()
    _up_forever_require_version(up_forever_python)

    string(REPLACE "_" "-" UF_PACKAGE "${PROJECT_NAME}")
    string(REPLACE "-" "_" UF_MODULE "${PROJECT_NAME}")
    if(arg_PACKAGE)
        set(UF_PACKAGE "${arg_PACKAGE}")
    endif()
    if(arg_MODULE)
        set(UF_MODULE "${arg_MODULE}")
    endif()
    if(NOT UF_MODULE MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
        message(FATAL_ERROR "up_forever_python: '${UF_MODULE}' can't be a Python module name (pass MODULE)")
    endif()
    string(TOUPPER "${UF_MODULE}" UF_ENV_PREFIX)
    configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../up_forever/version.py.in" "${arg_OUT}" @ONLY)
endfunction()

# Sets GIT_SHA and GIT_DIRTY in the caller: from the checkout when PROJECT_SOURCE_DIR is in one,
# else from UP_FOREVER_GIT_SHA/UP_FOREVER_GIT_DIRTY, else "unknown" and false.
function(_up_forever_git_provenance)
    set(head "")
    set(short "")
    set(dirty "false")
    find_package(Git QUIET)
    if(GIT_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse HEAD
            WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
            OUTPUT_VARIABLE head
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE head_result
            ERROR_QUIET
        )
        if(head_result EQUAL 0)
            execute_process(
                COMMAND "${GIT_EXECUTABLE}" rev-parse --short=12 HEAD
                WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                OUTPUT_VARIABLE short
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            execute_process(
                COMMAND "${GIT_EXECUTABLE}" status --porcelain
                WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                OUTPUT_VARIABLE changes
                ERROR_QUIET
            )
            if(NOT changes STREQUAL "")
                set(dirty "true")
            endif()
        else()
            set(head "")
        endif()
    endif()

    set(given_sha "")
    if(NOT UP_FOREVER_GIT_SHA STREQUAL "")
        string(TOLOWER "${UP_FOREVER_GIT_SHA}" given_sha)
        string(LENGTH "${given_sha}" given_length)
        if(NOT given_sha MATCHES "^[0-9a-f]+$" OR given_length LESS 12)
            message(FATAL_ERROR "UP_FOREVER_GIT_SHA must be a commit hash of 12 or more hex digits, got '${UP_FOREVER_GIT_SHA}'")
        endif()
    endif()
    set(given_dirty "")
    if(NOT UP_FOREVER_GIT_DIRTY STREQUAL "")
        string(TOUPPER "${UP_FOREVER_GIT_DIRTY}" flag)
        if(flag MATCHES "^(ON|YES|TRUE|Y|1)$")
            set(given_dirty "true")
        elseif(flag MATCHES "^(OFF|NO|FALSE|N|0)$")
            set(given_dirty "false")
        else()
            message(FATAL_ERROR "UP_FOREVER_GIT_DIRTY must be ON or OFF, got '${UP_FOREVER_GIT_DIRTY}'")
        endif()
    endif()

    if(NOT head STREQUAL "")
        string(FIND "${head}" "${given_sha}" at)
        if(NOT given_sha STREQUAL "" AND NOT at EQUAL 0)
            message(FATAL_ERROR "UP_FOREVER_GIT_SHA (${given_sha}) doesn't match this checkout's HEAD (${head}); unset it to use the checkout's commit")
        endif()
        if(NOT given_dirty STREQUAL "" AND NOT given_dirty STREQUAL dirty)
            message(FATAL_ERROR "UP_FOREVER_GIT_DIRTY says ${given_dirty}, but this checkout's dirty state is ${dirty}; unset it to use the checkout's state")
        endif()
        set(sha "${short}")
    elseif(NOT given_sha STREQUAL "")
        if(given_dirty STREQUAL "")
            message(FATAL_ERROR "UP_FOREVER_GIT_SHA needs UP_FOREVER_GIT_DIRTY=ON or OFF: outside a checkout up-forever can't see whether the tree had changes")
        endif()
        string(SUBSTRING "${given_sha}" 0 12 sha)
        set(dirty "${given_dirty}")
    elseif(NOT given_dirty STREQUAL "")
        message(FATAL_ERROR "UP_FOREVER_GIT_DIRTY only applies together with UP_FOREVER_GIT_SHA")
    else()
        set(sha "unknown")
    endif()

    set(GIT_SHA "${sha}" PARENT_SCOPE)
    set(GIT_DIRTY "${dirty}" PARENT_SCOPE)
endfunction()

# up_forever_build_info(TARGET <target> NAMESPACE <ns> OUT <file>)
#
# Writes an opt-in Build struct: the build configuration, plus the git commit, dirty flag and
# date. Its own header, apart from version.hpp: values that change every build recompile only
# the files that include them. Include it only from TARGET's sources, which get the
# configuration define.
function(up_forever_build_info)
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "TARGET;NAMESPACE;OUT" "")
    if(NOT arg_TARGET OR NOT arg_NAMESPACE OR NOT arg_OUT)
        message(FATAL_ERROR "up_forever_build_info: TARGET, NAMESPACE and OUT are required")
    endif()
    if(NOT TARGET "${arg_TARGET}")
        message(FATAL_ERROR "up_forever_build_info: ${arg_TARGET} isn't a target (create it first)")
    endif()

    _up_forever_git_provenance()

    string(TIMESTAMP hour "%H")
    if(hour LESS 12)
        set(meridiem "AM")
    else()
        set(meridiem "PM")
    endif()

    string(TIMESTAMP BUILD_DATE "%Y-%m-%d %H:%M:%S" UTC)
    string(TIMESTAMP BUILD_DATE_LOCAL "%Y-%m-%d %I:%M:%S ${meridiem}")

    set(VERSION_NAMESPACE "${arg_NAMESPACE}")
    configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../up_forever/build_info.hpp.in" "${arg_OUT}" @ONLY)
    # Empty $<CONFIG> means a single-config build with no CMAKE_BUILD_TYPE.
    target_compile_definitions(
        "${arg_TARGET}" PRIVATE "UP_FOREVER_BUILD_CONFIG=\"$<IF:$<BOOL:$<CONFIG>>,$<CONFIG>,None>\""
    )
endfunction()
