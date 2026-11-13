# Configures tests/fixtures/build_info in fresh trees and checks the provenance build_info.hpp gets.
#
#   cmake -DUP_FOREVER_ROOT=<repo> -DWORK=<scratch dir> -DCXX=<compiler> -DGIT=<git> -P build_info_provenance.cmake
cmake_minimum_required(VERSION 3.25)

foreach(required IN ITEMS UP_FOREVER_ROOT WORK CXX GIT)
    if(NOT DEFINED ${required})
        message(FATAL_ERROR "build_info_provenance.cmake needs -D${required}=...")
    endif()
endforeach()

set(fixture "${CMAKE_CURRENT_LIST_DIR}/fixtures/build_info")
file(REMOVE_RECURSE "${WORK}")
file(MAKE_DIRECTORY "${WORK}")
# Watch out: WORK sits inside up-forever's own checkout, and git walks up until it finds a .git.
# The ceiling stops it at WORK, so a case without `git init` really is outside any checkout.
set(ENV{GIT_CEILING_DIRECTORIES} "${WORK}")

function(git dir)
    # Signing is off so a signing agent (1Password's op-ssh-sign) can't stall on a prompt.
    execute_process(
        COMMAND "${GIT}" -c commit.gpgsign=false -c user.name=up-forever -c user.email=up-forever@test ${ARGN}
        WORKING_DIRECTORY "${dir}"
        OUTPUT_VARIABLE out
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_VARIABLE err
        RESULT_VARIABLE result
    )
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "git ${ARGN} failed: ${err}")
    endif()
    set(git_out "${out}" PARENT_SCOPE)
endfunction()

# Copies the fixture to WORK/<name>/src, optionally as a fresh one-commit checkout.
function(prepare name)
    cmake_parse_arguments(PARSE_ARGV 1 arg "CHECKOUT" "" "")
    set(src "${WORK}/${name}/src")
    file(COPY "${fixture}/" DESTINATION "${src}")
    if(arg_CHECKOUT)
        git("${src}" init -q)
        git("${src}" add .)
        git("${src}" commit -q -m fixture)
    endif()
endfunction()

# configure(<name> [EXPECT_SHA <sha> EXPECT_DIRTY <true|false>] [EXPECT_ERROR <regex>] [DEFINES -D...])
function(configure name)
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "EXPECT_SHA;EXPECT_DIRTY;EXPECT_ERROR" "DEFINES")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${WORK}/${name}/src" -B "${WORK}/${name}/build"
                "-DCMAKE_CXX_COMPILER=${CXX}" "-DUP_FOREVER_ROOT=${UP_FOREVER_ROOT}" ${arg_DEFINES}
        OUTPUT_QUIET
        ERROR_VARIABLE err
        RESULT_VARIABLE result
    )
    if(DEFINED arg_EXPECT_ERROR)
        if(result EQUAL 0)
            message(FATAL_ERROR "${name}: configure should have failed")
        endif()
        # CMake word-wraps FATAL_ERROR text, so a phrase can straddle a line break.
        string(REGEX REPLACE "[ \t\r\n]+" " " err "${err}")
        if(NOT err MATCHES "${arg_EXPECT_ERROR}")
            message(FATAL_ERROR "${name}: expected an error matching '${arg_EXPECT_ERROR}', got:\n${err}")
        endif()
        message(STATUS "${name}: failed as expected")
        return()
    endif()
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "${name}: configure failed:\n${err}")
    endif()
    file(READ "${WORK}/${name}/build/build_info.hpp" header)
    if(NOT header MATCHES "git_sha += \"${arg_EXPECT_SHA}\"")
        message(FATAL_ERROR "${name}: expected git_sha \"${arg_EXPECT_SHA}\" in:\n${header}")
    endif()
    if(NOT header MATCHES "git_dirty += ${arg_EXPECT_DIRTY};")
        message(FATAL_ERROR "${name}: expected git_dirty ${arg_EXPECT_DIRTY} in:\n${header}")
    endif()
    message(STATUS "${name}: git_sha ${arg_EXPECT_SHA}, git_dirty ${arg_EXPECT_DIRTY}")
endfunction()

set(sha "ABCDEF0123456789ABCDEF0123456789ABCDEF01")

# Outside a checkout.
prepare(plain)
configure(plain EXPECT_SHA unknown EXPECT_DIRTY false)

prepare(given)
configure(given EXPECT_SHA abcdef012345 EXPECT_DIRTY false
    DEFINES "-DUP_FOREVER_GIT_SHA=${sha}" -DUP_FOREVER_GIT_DIRTY=OFF)

prepare(given_dirty)
configure(given_dirty EXPECT_SHA abcdef012345 EXPECT_DIRTY true
    DEFINES "-DUP_FOREVER_GIT_SHA=${sha}" -DUP_FOREVER_GIT_DIRTY=ON)

prepare(sha_without_dirty)
configure(sha_without_dirty EXPECT_ERROR "needs UP_FOREVER_GIT_DIRTY=ON or OFF"
    DEFINES "-DUP_FOREVER_GIT_SHA=${sha}")

prepare(dirty_without_sha)
configure(dirty_without_sha EXPECT_ERROR "only applies together with UP_FOREVER_GIT_SHA"
    DEFINES -DUP_FOREVER_GIT_DIRTY=OFF)

prepare(short_sha)
configure(short_sha EXPECT_ERROR "12 or more hex digits"
    DEFINES -DUP_FOREVER_GIT_SHA=abc1234 -DUP_FOREVER_GIT_DIRTY=OFF)

prepare(not_a_sha)
configure(not_a_sha EXPECT_ERROR "12 or more hex digits"
    DEFINES -DUP_FOREVER_GIT_SHA=release-1.2.3-final -DUP_FOREVER_GIT_DIRTY=OFF)

prepare(bad_dirty)
configure(bad_dirty EXPECT_ERROR "must be ON or OFF"
    DEFINES "-DUP_FOREVER_GIT_SHA=${sha}" -DUP_FOREVER_GIT_DIRTY=maybe)

# Inside a checkout, git decides and overrides have to agree with it.
prepare(checkout CHECKOUT)
git("${WORK}/checkout/src" rev-parse --short=12 HEAD)
configure(checkout EXPECT_SHA "${git_out}" EXPECT_DIRTY false)

prepare(checkout_agrees CHECKOUT)
git("${WORK}/checkout_agrees/src" rev-parse HEAD)
string(TOUPPER "${git_out}" agreeing)
git("${WORK}/checkout_agrees/src" rev-parse --short=12 HEAD)
configure(checkout_agrees EXPECT_SHA "${git_out}" EXPECT_DIRTY false
    DEFINES "-DUP_FOREVER_GIT_SHA=${agreeing}" -DUP_FOREVER_GIT_DIRTY=OFF)

prepare(checkout_conflict CHECKOUT)
configure(checkout_conflict EXPECT_ERROR "doesn't match this checkout's HEAD"
    DEFINES "-DUP_FOREVER_GIT_SHA=${sha}")

prepare(checkout_dirty CHECKOUT)
file(WRITE "${WORK}/checkout_dirty/src/uncommitted.txt" "changed\n")
configure(checkout_dirty EXPECT_ERROR "dirty state is true"
    DEFINES -DUP_FOREVER_GIT_DIRTY=OFF)
