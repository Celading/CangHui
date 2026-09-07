#!/usr/bin/env python3
"""Validate the immutable SDK default against Git objects, without network or writes."""
import pathlib
import re
import subprocess
import sys


def check(root: pathlib.Path) -> None:
    source = (root / "tools/cuic/src/dependency.cj").read_text()
    match = re.search(r'let DEFAULT_CANGHUI_COMMIT = "([0-9a-f]{40})"', source)
    if not match:
        raise ValueError("SDK default must be an exact 40-character commit")
    commit = match[1]

    def git_file(path: str) -> str:
        return subprocess.check_output(
            ["git", "-C", str(root), "show", f"{commit}:{path}"], text=True
        )

    manifest = git_file("cjpm.toml")
    if not re.search(r'^name\s*=\s*"chui"\s*$', manifest, re.M):
        raise ValueError(f"SDK default {commit} does not publish package chui")
    # The root marker is also used by the CLI to discover the resolved dependency.
    git_file("src/chui.cj")
    git_file("sdl/cjpm.toml")
    template = (root / "tools/cuic/src/main.cj").read_text()
    if "import chui.{" not in template:
        raise ValueError("SDK template does not use the declared public package")
    print(f"SDK default identity passed: {commit} / chui")


if __name__ == "__main__":
    try:
        check(pathlib.Path(__file__).resolve().parent.parent)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"SDK default identity failed: {error}", file=sys.stderr)
        sys.exit(1)
