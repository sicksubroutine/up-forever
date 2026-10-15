# Up Forever

Simple Versioning

> Forged with [cpp-forge](https://github.com/sicksubroutine/cpp-forge) 🔨

## Quick start

```bash
mask check
mask run
```

`mask configure` uses Clang by default and generates `build/compile_commands.json` for clangd. It prefers `CLANGXX`, then Homebrew LLVM or a versioned Clang, before falling back to the platform `clang++`. Switch the same build tree explicitly with `mask configure gcc` or `mask configure clang`; cpp-forge safely recreates the tree when the compiler changes.

## Layout

```text
up-forever/
├── cmake/
│   ├── BumpVersion.cmake
│   ├── HeaderSelfContainment.cmake
│   └── version.hpp.in.jinja
├── include/
│   └── up_forever/
│       └── example.hpp
├── scripts/
│   ├── configure.sh
│   ├── format.sh
│   ├── publish.sh
│   └── release.sh
├── src/
│   └── main.cpp
├── tests/
│   ├── test_example.cpp
│   └── test_version.cpp
├── .clang-format
├── .clang-tidy
├── .clangd
├── CMakeLists.txt
├── CHANGELOG.md
├── VERSION
└── maskfile.md
```

## Development commands

| Command | Description |
|---|---|
| `mask configure [clang\|gcc]` | Configure the current toolchain or switch compilers |
| `mask build` | Configure and build every target |
| `mask run` | Build and run the executable |
| `mask test` | Build and run every discovered doctest case through CTest |
| `mask format` | Format owned C and C++ sources |
| `mask check` | Verify formatting, then build and test |
| `mask sanitize [clang\|gcc]` | Run tests under ASan and UBSan with the active or selected compiler |
| `mask release <kind>` | Check, bump, commit, and tag locally |
| `mask publish` | Confirm and atomically push the current branch and tag |

Every public header beneath `include/`, plus generated public headers, is compiled in its own translation unit. This catches missing direct includes and accidental include-order dependencies under both supported compilers. Set `CLANG_FORMAT` to override formatter discovery; otherwise cpp-forge uses `clang-format` from `PATH` or the Homebrew LLVM installation.

## Versioning and releases

`VERSION` is the sole tracked source of truth used by CMake to generate `<up_forever/version.hpp>`.

```bash
mask version
mask bump patch
mask release minor
mask publish
```

`mask release` refuses a dirty worktree and never pushes. `mask publish` requires the matching local tag to point at `HEAD`, asks for confirmation, and pushes the branch and tag atomically.

## Author

chaz <bright.lid5647@fastmail.com>
