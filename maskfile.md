# Up Forever

## configure [compiler]

> Configure a development build and refresh `build/compile_commands.json`. Pass `clang` or `gcc` to switch toolchains.

```bash
bash scripts/configure.sh "${compiler:-}" build
```

## version

> Print the current project version.

```bash
cmake -E cat VERSION
```

## bump (kind)

> Bump `VERSION` without committing, tagging, pushing, or publishing.

```bash
cmake -DKIND="${kind}" -P cmake/BumpVersion.cmake
version="$(tr -d '\r\n' < VERSION)"
$MASK configure >/dev/null
```

## release (kind)

> Check, bump, commit the version files, and create an annotated local tag without pushing.

```bash
bash scripts/release.sh "${kind}"
```

## publish

> After confirmation, atomically push the current branch and its matching version tag.

```bash
bash scripts/publish.sh
```

## build

> Configure and build every target.

```bash
$MASK configure
cmake --build build
```

## run [args]

> Build and run the executable, forwarding optional arguments.

```bash
$MASK build >/dev/null
./build/bin/up-forever ${args:-}
```

## test

> Build and run every registered test. An empty suite is an error.

```bash
set -e
$MASK build
ctest --test-dir build --output-on-failure --no-tests=error
```

## list-tests

> Build, then list the registered tests without running them.

```bash
$MASK build >/dev/null
ctest --test-dir build --show-only
```

## format

> Format owned C and C++ sources.

```bash
bash scripts/format.sh format
```

## format-check

> Verify owned C and C++ sources already match `.clang-format`.

```bash
bash scripts/format.sh check
```

## sanitize [compiler]

> Build and run the complete test suite under AddressSanitizer and UndefinedBehaviorSanitizer, using the active compiler by default.

```bash
set -e
$MASK configure "${compiler:-}"
cxx="$(sed -n 's/^CMAKE_CXX_COMPILER:[^=]*=//p' build/CMakeCache.txt | head -n 1)"
bash scripts/configure.sh "$cxx" build-sanitize \
    -DUP_FOREVER_ENABLE_SANITIZERS=ON
cmake --build build-sanitize
ctest --test-dir build-sanitize --output-on-failure --no-tests=error
```

## check

> Run the normal local quality gate.

```bash
set -e
$MASK format-check
$MASK test
```

## clean

> Clean the configured normal build.

```bash
cmake --build build --target clean
```

## nuke [compiler]

> Remove generated build trees, then configure a fresh normal build.

```bash
cmake -E remove_directory build
cmake -E remove_directory build-sanitize
$MASK configure "${compiler:-}"
```

## changelog

> Generate changelog locally from git tags. No CI needed.

```bash
uv tool run git-changelog --config-file config/git-changelog.toml
git add CHANGELOG.md
git commit -m "chore: update changelog for $(git describe --tags --abbrev=0)"
```
