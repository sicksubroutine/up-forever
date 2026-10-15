#!/usr/bin/env bash
set -euo pipefail

kind="${1:-}"
if [[ ! "$kind" =~ ^(patch|minor|major)$ ]]; then
    echo "Usage: $0 <patch|minor|major>"
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Release preparation requires a clean working tree."
    git status --short
    exit 1
fi

if ! git symbolic-ref --quiet --short HEAD >/dev/null; then
    echo "Release preparation requires a checked-out branch, not detached HEAD."
    exit 1
fi

version_probe="$(mktemp)"
trap 'rm -f "$version_probe"' EXIT
cmake -E copy VERSION "$version_probe"
cmake -DVERSION_FILE="$version_probe" -DKIND="$kind" -P cmake/BumpVersion.cmake >/dev/null
version="$(tr -d '\r\n' < "$version_probe")"
tag="v${version}"

if git rev-parse --verify --quiet "refs/tags/${tag}" >/dev/null; then
    echo "Tag ${tag} already exists."
    exit 1
fi

mask check
cmake -DKIND="$kind" -P cmake/BumpVersion.cmake
mask configure >/dev/null

git add VERSION
git commit -m "chore: release ${tag}"
git tag -a "$tag" -m "Release ${tag}"

echo "Prepared ${tag} locally. Review it, then run: mask publish"
