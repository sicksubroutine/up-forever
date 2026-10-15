#!/usr/bin/env bash
set -euo pipefail

mode="${1:-format}"
formatter="${CLANG_FORMAT:-}"

if [[ -z "$formatter" ]] && command -v clang-format >/dev/null 2>&1; then
    formatter="$(command -v clang-format)"
fi

if [[ -z "$formatter" ]] && command -v brew >/dev/null 2>&1; then
    llvm_prefix="$(brew --prefix llvm 2>/dev/null || true)"
    if [[ -x "${llvm_prefix}/bin/clang-format" ]]; then
        formatter="${llvm_prefix}/bin/clang-format"
    fi
fi

if [[ -z "$formatter" ]]; then
    for candidate in clang-format-23 clang-format-22 clang-format-21 clang-format-20 clang-format-19 clang-format-18; do
        if command -v "$candidate" >/dev/null 2>&1; then
            formatter="$(command -v "$candidate")"
            break
        fi
    done
fi

if [[ -z "$formatter" ]] || [[ ! -x "$formatter" ]]; then
    echo "Unable to find clang-format. Set CLANG_FORMAT or install LLVM." >&2
    exit 1
fi

case "$mode" in
    format)
        args=(-i)
        ;;
    check)
        args=(--dry-run --Werror)
        ;;
    *)
        echo "Usage: $0 [format|check]" >&2
        exit 1
        ;;
esac

find include src tests -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) -print0 \
    | xargs -0 "$formatter" "${args[@]}"
