#!/usr/bin/env python3
"""Capture owned native study windows; each image retains its real frame clock."""
import argparse
import json
import os
from pathlib import Path
import struct
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--full", action="store_true", help="add narrow, dark, scaled and reduced cases")
args = parser.parse_args()
project = Path(__file__).resolve().parent
root = project.parent.parent
binary = project / "target/release/bin/main"
args.output.mkdir(parents=True, exist_ok=True)
manifest = []
cases = [(i, 1060, "light", False, "1", frames) for i in range(5) for frames in [2, 12, 32, 80]]
if args.full:
    cases += [(i, width, theme, reduced, scale, 80) for i in range(5)
              for width, theme, reduced, scale in [(390, "light", False, "1"),
                                                 (1060, "dark", False, "1"),
                                                 (390, "dark", True, "1.5")]]
for family, width, theme, reduced, scale, frames in cases:
    key = f"f{family}-w{width}-{theme}-r{int(reduced)}-s{scale}-n{frames}"
    image = args.output / (key + ".png")
    env = dict(os.environ)
    env.update(DYLD_LIBRARY_PATH=str(root / "sdl/.sdl3"),
               CANGHUI_HARMONYOS_SANS=str(root / "assets/fonts/HarmonyOS_Sans_SC.ttf"),
               CANGHUI_CAPTURE_PATH=str(image.resolve()), CANGHUI_CAPTURE_FRAMES=str(frames))
    command = [str(binary), "--family", str(family), "--width", str(width), "--height", "900",
               "--theme", theme, "--reduced", str(reduced).lower(), "--scale", scale, "--pointer", "true"]
    result = subprocess.run(command, cwd=project, env=env, capture_output=True, text=True, timeout=45)
    (args.output / (key + ".log")).write_text(result.stdout + result.stderr)
    if result.returncode or not image.is_file():
        raise SystemExit(f"Native case {key} failed: {result.returncode}: {result.stderr[-1500:]}")
    raw = image.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"Not a PNG: {key}")
    dimensions = list(struct.unpack(">II", raw[16:24]))
    receipt = next((line.removeprefix("MOTION_STUDY_RESULT ") for line in result.stdout.splitlines()
                    if line.startswith("MOTION_STUDY_RESULT ")), "null")
    manifest.append(dict(case=key, family=family, width=width, theme=theme, reduced=reduced,
                         scale=scale, captureFrames=frames, image=image.name, dimensions=dimensions,
                         runtime=json.loads(receipt), nativeHost="macOS", opticalBlurVerified=False))
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Captured {key}", flush=True)
