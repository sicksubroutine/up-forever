# Up Forever

Simple Versioning

One version header for every project, from one template. A project calls `up_forever_header()`
and gets a flat, self-contained `Version` struct built from its own `project()`: no copied
template files to drift, no library types to depend on.

## Usage

```cmake
project(my_app VERSION 1.2.3 LANGUAGES CXX)

include(FetchContent)
FetchContent_Declare(
    up_forever
    GIT_REPOSITORY git@github.com:sicksubroutine/up-forever.git
    GIT_TAG        <commit sha>   # pin a commit, so old checkouts keep building
)
FetchContent_MakeAvailable(up_forever)

up_forever_header(NAMESPACE my_app OUT "${CMAKE_CURRENT_BINARY_DIR}/generated/include/my_app/version.hpp")
```

`NAMESPACE` and `OUT` are required. The name and version come from the calling `project()`, which
must have a `MAJOR.MINOR.PATCH` version.

## The header

```cpp
#include <my_app/version.hpp>

my_app::Version::name         // "my_app"
my_app::Version::version      // "1.2.3"
my_app::Version::full_string  // "my_app v1.2.3"
my_app::Version::major        // 1  (minor, patch likewise; uint16_t)
my_app::Version::numeric      // major << 32 | minor << 16 | patch, for comparisons
my_app::Version::at_least(1, 2)  // true; minor and patch default to 0
```

Everything is `constexpr`, and it includes only `<cstdint>` and `<string_view>`.

## Build info (optional)

A second, separate header for what changes from build to build. It's kept out of `version.hpp`
so a new commit or date only recompiles the files that ask for it (your `--version` or crash log).

```cmake
add_executable(my_app ...)
up_forever_build_info(TARGET my_app NAMESPACE my_app OUT "${CMAKE_CURRENT_BINARY_DIR}/generated/include/my_app/build_info.hpp")
```

```cpp
#include <my_app/build_info.hpp>   // only from my_app's own sources

my_app::Build::configuration  // "Debug", "Release", "RelWithDebInfo", "MinSizeRel", or "None"
my_app::Build::debug          // configuration == "Debug"
my_app::Build::release        // any of the three release configurations
my_app::Build::git_sha        // "b1bf1e7e2f3a", or "unknown" outside a git checkout
my_app::Build::git_dirty      // uncommitted changes when CMake configured
my_app::Build::date           // "2026-10-15", UTC (honors SOURCE_DATE_EPOCH)
```

- **The configuration comes from the target at build time** (a compile definition), because
  multi-config generators like Xcode and Visual Studio only know it then. Including the header from
  a different target is a compile error that says so.
- **The git values and date are captured when CMake configures**, so they update on the next
  reconfigure, not on every build.

## Notes

- **Offline or local work:** `-DFETCHCONTENT_SOURCE_DIR_UP_FOREVER=/path/to/up-forever` uses a
  local checkout and skips the download.
- **Several layers can declare it:** FetchContent's first declaration wins, so a project and its
  dependencies can each declare `up_forever` and only one copy is fetched.
- **Consumers only get the function:** the root `CMakeLists.txt` returns early when up-forever
  isn't the top-level build, so its tests and targets never land in a consumer's build.

## Developing

Build it as the top-level project to run its tests; its own header comes from the same function
consumers call.

```bash
cmake -S . -B build && cmake --build build -j4 && ctest --test-dir build
```
