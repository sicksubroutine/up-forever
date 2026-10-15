#!/usr/bin/env bash
set -euo pipefail

requested_compiler="${1:-}"
build_dir="${2:-build}"
if (( $# >= 2 )); then
    shift 2
else
    shift "$#"
fi

cache_file="${build_dir}/CMakeCache.txt"

resolve_compiler() {
    local requested="$1"
    local candidate=""

    case "$requested" in
        clang)
            if [[ -n "${CLANGXX:-}" ]]; then
                candidate="$CLANGXX"
            elif command -v brew >/dev/null 2>&1; then
                local llvm_prefix
                llvm_prefix="$(brew --prefix llvm 2>/dev/null || true)"
                if [[ -x "${llvm_prefix}/bin/clang++" ]]; then
                    candidate="${llvm_prefix}/bin/clang++"
                fi
            fi

            if [[ -z "$candidate" ]]; then
                local clang_candidate
                for clang_candidate in clang++-23 clang++-22 clang++-21 clang++-20 clang++-19 clang++-18 clang++; do
                    if command -v "$clang_candidate" >/dev/null 2>&1; then
                        candidate="$clang_candidate"
                        break
                    fi
                done
            fi
            ;;
        gcc)
            if [[ -n "${GXX:-}" ]]; then
                candidate="$GXX"
            else
                local gcc_candidate
                for gcc_candidate in g++-20 g++-19 g++-18 g++-17 g++-16 g++-15 g++-14 g++-13 g++-12 g++; do
                    if ! command -v "$gcc_candidate" >/dev/null 2>&1; then
                        continue
                    fi
                    if "$gcc_candidate" --version 2>&1 | head -n 1 | grep -qi clang; then
                        continue
                    fi
                    candidate="$gcc_candidate"
                    break
                done
            fi
            ;;
        *)
            candidate="$requested"
            ;;
    esac

    if [[ -z "$candidate" ]] || ! command -v "$candidate" >/dev/null 2>&1; then
        echo "Unable to find C++ compiler '${requested}'. Set CLANGXX/GXX or pass an executable path." >&2
        return 1
    fi

    command -v "$candidate"
}

if [[ -z "$requested_compiler" && -f "$cache_file" ]]; then
    cmake -S . -B "$build_dir" -DCMAKE_BUILD_TYPE="${BUILD_TYPE:-Debug}" "$@"
    exit 0
fi

requested_compiler="${requested_compiler:-gcc}"
compiler_path="$(resolve_compiler "$requested_compiler")"
current_compiler=""
if [[ -f "$cache_file" ]]; then
    current_compiler="$(sed -n 's/^CMAKE_CXX_COMPILER:[^=]*=//p' "$cache_file" | head -n 1)"
fi

if [[ -n "$current_compiler" && "$current_compiler" != "$compiler_path" ]]; then
    echo "Switching C++ compiler: ${current_compiler} -> ${compiler_path}"
    cmake -E remove_directory "$build_dir"
fi

cmake -S . -B "$build_dir" \
    -DCMAKE_CXX_COMPILER="$compiler_path" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE:-Debug}" \
    "$@"
