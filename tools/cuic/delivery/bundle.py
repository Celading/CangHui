#!/usr/bin/env python3
"""Assemble a standalone CUIC directory with a trusted private NSIS engine."""
import argparse
import json
from pathlib import Path
import shutil
import sys
from installer import check_engine, digest, inventory, no_links


def bundle(binary, engine, output):
    binary, engine, output = (Path(p).absolute() for p in (binary, engine, output))
    for path in (binary, engine, output):
        no_links(path)
    info, _ = check_engine(engine)
    if not binary.is_file():
        raise ValueError("CUIC binary missing")
    if output.is_relative_to(engine) or engine.is_relative_to(output) or binary.is_relative_to(output):
        raise ValueError("bundle output overlaps its inputs")
    output.mkdir(parents=True, exist_ok=False)
    exe = "cuic.exe" if sys.platform == "win32" else "cuic"
    shutil.copy2(binary, output / exe)
    resources = output / "cuic-delivery"
    resources.mkdir()
    for name in ("installer.py", "seal_engine.py"):
        shutil.copyfile(Path(__file__).parent / name, resources / name)
    shutil.copytree(engine, resources / "engines/nsis")
    check_engine(resources / "engines/nsis")
    license_path = Path(__file__).resolve().parents[3] / "LICENSE"
    shutil.copyfile(license_path, output / "CangHui-LICENSE.txt")
    receipt = {"schema": "chui.delivery-bundle.v1", "host": info["host"],
               "engineVersion": info["version"], "cuicSha256": digest(binary),
               "pythonMinimum": "3.11", "nativeRuntimeClosureVerified": False,
               "files": inventory(output)}
    (output / "bundle.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--cuic", required=True)
    p.add_argument("--engine", required=True)
    p.add_argument("--output", required=True)
    a = p.parse_args()
    try:
        print(json.dumps(bundle(a.cuic, a.engine, a.output), indent=2))
    except (ValueError, OSError) as error:
        p.exit(1, f"error: {error}\n")


if __name__ == "__main__":
    main()
