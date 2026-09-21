#!/usr/bin/env python3
"""Prepare the canghui-package Honor format fork from trusted NSIS 3.12 source.

Build both makensis and stubs from the result. This is format obfuscation, not
encryption, DRM, signature verification, or a guarantee against reverse engineering.
"""
import argparse
from pathlib import Path
import shutil

ORIGINAL = ("#define FH_SIG 0xDEADBEEF", "#define FH_INT1 0x6C6C754E",
            "#define FH_INT2 0x74666F73", "#define FH_INT3 0x74736E49")
REPLACEMENT = ("#define FH_SIG 0x43485549", "#define FH_INT1 0x726F6E48",
               "#define FH_INT2 0x726F4631", "#define FH_INT3 0x2174616D")


def prepare(source, output):
    source, output = Path(source).resolve(strict=True), Path(output).absolute()
    if output.exists() or output.is_relative_to(source):
        raise ValueError("use a new source copy outside the original tree")
    header = source / "Source/exehead/fileform.h"
    text = header.read_text()
    for old in ORIGINAL:
        if text.count(old) != 1:
            raise ValueError("unexpected upstream firstheader constants; review this version first")
    # Ignore generated objects and local build configuration. Never modify upstream in place.
    shutil.copytree(source, output, ignore=shutil.ignore_patterns(
        "build", ".git", ".sconsign*", ".sconf*", "__pycache__", "config.log"))
    for old, new in zip(ORIGINAL, REPLACEMENT):
        text = text.replace(old, new)
    (output / "Source/exehead/fileform.h").write_text(text)
    (output / "CANGHUI-HONOR-CHANGES.txt").write_text(
        "canghui-package Honor format v1: four firstheader identifiers changed in "
        "Source/exehead/fileform.h. Compiler and reader must be built together. "
        "PE loader headers and CRC remain unchanged. Upstream NSIS license retained.\n")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source")
    p.add_argument("output")
    a = p.parse_args()
    prepare(a.source, a.output)
