#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Publishing requires a clean working tree."
    git status --short
    exit 1
fi

branch="$(git symbolic-ref --quiet --short HEAD)" || {
    echo "Publishing requires a checked-out branch, not detached HEAD."
    exit 1
}

version="$(tr -d '\r\n' < VERSION)"
tag="v${version}"

if ! git rev-parse --verify --quiet "refs/tags/${tag}" >/dev/null; then
    echo "Local tag ${tag} does not exist. Run mask release first."
    exit 1
fi

head_commit="$(git rev-parse HEAD)"
tag_commit="$(git rev-list -n 1 "$tag")"
if [[ "$tag_commit" != "$head_commit" ]]; then
    echo "Tag ${tag} does not point at HEAD. Refusing to publish."
    exit 1
fi

printf 'Atomically push branch %s and tag %s to origin? [y/N] ' "$branch" "$tag"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Publish cancelled."
    exit 1
fi

git push --atomic origin "$branch" "$tag"
