include_guard(GLOBAL)

function(add_header_self_containment_target target)
    set(multi_value_args HEADER_ROOTS LINK_LIBRARIES)
    cmake_parse_arguments(ARG "" "" "${multi_value_args}" ${ARGN})

    set(probe_dir "${CMAKE_CURRENT_BINARY_DIR}/header-self-containment/${target}")
    set(probe_sources)
    set(include_dirs)
    set(root_index 0)

    foreach(header_root IN LISTS ARG_HEADER_ROOTS)
        if(NOT IS_DIRECTORY "${header_root}")
            continue()
        endif()

        list(APPEND include_dirs "${header_root}")
        file(
            GLOB_RECURSE headers
            CONFIGURE_DEPENDS
            LIST_DIRECTORIES FALSE
            RELATIVE "${header_root}"
            "${header_root}/*.h"
            "${header_root}/*.hh"
            "${header_root}/*.hpp"
            "${header_root}/*.hxx"
        )

        foreach(header IN LISTS headers)
            string(MAKE_C_IDENTIFIER "${root_index}_${header}" probe_name)
            set(probe "${probe_dir}/${probe_name}.cpp")
            file(GENERATE OUTPUT "${probe}" CONTENT "#include <${header}>\n")
            list(APPEND probe_sources "${probe}")
        endforeach()

        math(EXPR root_index "${root_index} + 1")
    endforeach()

    if(NOT probe_sources)
        message(FATAL_ERROR "${target} has no headers to check")
    endif()

    add_library("${target}" OBJECT ${probe_sources})
    target_include_directories("${target}" PRIVATE ${include_dirs})
    target_link_libraries("${target}" PRIVATE ${ARG_LINK_LIBRARIES})
    set_target_properties("${target}" PROPERTIES CXX_EXTENSIONS OFF)
endfunction()
