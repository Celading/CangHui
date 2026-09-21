#!/usr/bin/env python3
"""Compile both real NSIS modes around an explicit Windows EXE; never execute it."""
import argparse
import json
from pathlib import Path
import shutil
import tempfile
from installer import build


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--engine", type=Path, required=True)
    p.add_argument("--entry", type=Path, required=True)
    a = p.parse_args()
    with tempfile.TemporaryDirectory(prefix="chui-real-installer-") as work:
        root = Path(work).resolve()
        (root / "payload/资源").mkdir(parents=True)
        shutil.copyfile(a.entry, root / "payload/App.exe")
        (root / "payload/资源/Space File.txt").write_text("resource fixture", encoding="utf-8")
        (root / "canghui.toml").write_text('[application]\nname="仓绘 Smoke"\nidentifier="dev.chui.smoke"\nversion="1.0.0"\n', encoding="utf-8")
        results = []
        for mode in ("install", "portable"):
            request = argparse.Namespace(project=str(root), payload="payload", entry="App.exe",
                                         output=f"dist/{mode}", mode=mode,
                                         engine_bundle=str(a.engine.resolve()), honor_system=True)
            receipt = build(request)
            assert receipt["compiled"] and not receipt["windowsExecutionVerified"]
            results.append({"mode": mode, "sha256": receipt["sha256"], "compiled": True,
                            "windowsExecutionVerified": False})
        print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
