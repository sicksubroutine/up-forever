"""Checks a version.py that up_forever_python() wrote.

Usage: test_version_py.py <version.py> <version> <package> <module> <env variable> <project>
"""

import importlib.util
import sys
from _frozen_importlib import ModuleSpec
from types import ModuleType
from typing import Any


def main() -> int:
    path, version, package, module, env, project = sys.argv[1:7]
    spec: ModuleSpec | None = importlib.util.spec_from_file_location("generated_version", path)
    assert spec is not None and spec.loader is not None, f"can't load {path}"
    v: ModuleType = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(v)

    expected_tuple: tuple[int, ...] = tuple(int(part) for part in version.split("."))
    checks: dict[
        str,
        tuple[Any, str] | tuple[Any, tuple[int, ...]] | tuple[tuple[Any, Any, Any], tuple[int, ...]] | tuple[Any, bool],
    ] = {
        "version":              (v.version, version),
        "version_tuple":        (v.version_tuple, expected_tuple),
        "MAJOR/MINOR/PATCH":    ((v.MAJOR, v.MINOR, v.PATCH), expected_tuple),
        "PACKAGE_NAME":         (v.PACKAGE_NAME, package),
        "MODULE_NAME":          (v.MODULE_NAME, module),
        "ENV_VARIABLE":         (v.ENV_VARIABLE, env),
        "full_version":         (v.full_version, f"{project} v{version}"),
        "at_least(itself)":     (v.at_least(*expected_tuple), True),
        "at_least(next major)": (v.at_least(expected_tuple[0] + 1), False),
    }
    failed: list[str] = [f"{name}: got {got!r}, expected {want!r}" for name, (got, want) in checks.items() if got != want]
    for line in failed:
        print(line, file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
