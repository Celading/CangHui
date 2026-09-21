#!/usr/bin/env python3
"""Seal an explicitly trusted canghui-package engine directory; no downloads."""
import argparse
import json
from pathlib import Path
import sys
from installer import SCHEMA, check_engine, host_tag, inventory


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("directory", type=Path)
    p.add_argument("--version", required=True)
    p.add_argument("--source-sha256", required=True)
    p.add_argument("--templates-sha256", required=True)
    p.add_argument("--honor-profile", action="store_true")
    args = p.parse_args()
    import re
    for value in (args.source_sha256, args.templates_sha256):
        if not re.fullmatch("[0-9a-f]{64}", value):
            p.error("upstream SHA-256 must contain 64 lowercase hex digits")
    root = args.directory.absolute()
    files = inventory(root)
    if "engine.json" in files:
        p.error("engine is already sealed; use a new directory")
    manifest = {"schema": SCHEMA, "host": host_tag(), "version": args.version,
                "engine": "canghui-package", "backend": "NSIS",
                "upstreamSourceSha256": args.source_sha256,
                "upstreamTemplatesSha256": args.templates_sha256, "files": files}
    if args.honor_profile:
        manifest["honorFormat"] = "chui-honor-v1"
    with (root / "engine.json").open("x", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2)
        stream.write("\n")
    check_engine(root)
    print("Sealed private engine; inventory integrity is not publisher authentication.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
