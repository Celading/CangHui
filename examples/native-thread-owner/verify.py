#!/usr/bin/env python3
"""macOS-only native lifecycle regression, ordinary cjpm run, no capture overrides."""
import argparse
import json
import os
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--output", type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
env = os.environ.copy()
for key in list(env):
    if key == "cjProcessorNum" or key.startswith("CUIC_CAPTURE") or key.startswith("CANGHUI_CAPTURE"):
        env.pop(key)
root = Path(__file__).resolve().parent
env["DYLD_LIBRARY_PATH"] = str(root.parents[1] / "sdl/.sdl3")
cases = []
for i in range(22):
    args = ["--implicit"] if i < 10 else ([] if i < 20 else ["--throw"])
    run = subprocess.run(["cjpm", "run", "--", *args], cwd=root, env=env,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
    text = run.stdout.decode(errors="replace")
    (a.output / f"run-{i:02}.log").write_text(text)
    # cjpm versions have differed in forwarding the child exit status: inspect proof too.
    if (run.returncode or "phase=created" not in text or "owner mismatch" in text
            or "Exception:" in text or (i < 20 and "phase=async-5" not in text)
            or (i >= 20 and "primary-exception-preserved" not in text)):
        raise SystemExit(f"failed run {i}; see retained log")
    cases.append({"run": i, "args": args, "passed": True})
(a.output / "receipt.json").write_text(json.dumps({"schema": "chui.native-owner-replay.v1",
    "cases": cases, "processorOverride": False, "nativeDialogsVerified": False}, indent=2) + "\n")
print(f"Passed {len(cases)} ordinary launches; native file-dialog interaction remains separate.")
