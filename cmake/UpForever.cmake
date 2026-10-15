include_guard(GLOBAL)

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
    if(NOT PROJECT_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
        message(FATAL_ERROR "up_forever_header: project(${PROJECT_NAME}) needs VERSION MAJOR.MINOR.PATCH, got '${PROJECT_VERSION}'")
    endif()

    set(VERSION_NAMESPACE "${arg_NAMESPACE}")
    # The function's own directory, not the caller's: that's what lets any consumer call it.
    configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../up_forever/version.hpp.in" "${arg_OUT}" @ONLY)
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

    set(GIT_SHA "unknown")
    set(GIT_DIRTY "false")
    find_package(Git QUIET)
    if(GIT_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse --short=12 HEAD
            WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
            OUTPUT_VARIABLE sha
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE sha_result
            ERROR_QUIET
        )
        if(sha_result EQUAL 0)
            set(GIT_SHA "${sha}")
            execute_process(
                COMMAND "${GIT_EXECUTABLE}" status --porcelain
                WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                OUTPUT_VARIABLE changes
                ERROR_QUIET
            )
            if(NOT changes STREQUAL "")
                set(GIT_DIRTY "true")
            endif()
        endif()
    endif()

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
