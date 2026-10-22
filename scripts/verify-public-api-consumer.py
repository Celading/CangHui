#!/usr/bin/env python3
"""Build a real external facade consumer and check its recorded rendering contract."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def verify_scenes(output):
    scenes = [json.loads(line) for line in output.splitlines() if line.startswith('{"dark":')]
    if len(scenes) != 8 or "PUBLIC_API_CONSUMER_PASS" not in output.splitlines():
        raise ValueError("consumer did not complete all eight scenes")
    expected_states = {(dark, selected, expanded)
                       for dark in (False, True) for selected in (False, True)
                       for expanded in (False, True)}
    if {(s["dark"], s["selected"], s["expanded"]) for s in scenes} != expected_states:
        raise ValueError("theme/selection/expansion coverage is incomplete")
    for scene in scenes:
        commands = [c["data"] for c in scene["commands"] if c["kind"] == "symbol"]
        expected = [("consumer-fixture", "folder", False)]
        if scene["expanded"]:
            expected.append(("consumer-fixture", "file", False))
        expected.append(("builtin", "missing", True))
        actual = [(c["provider"], c["name"], c["fallback"]) for c in commands]
        if actual != expected:
            raise ValueError(f"provider, precedence, child visibility or fallback mismatch: {actual}")
    return scenes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="optional verification receipt")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    fixture = root / "tools/release-fixtures/public-api-consumer"
    result = {"ok": False}
    try:
        with tempfile.TemporaryDirectory(prefix="chui-public-api-") as temporary:
            consumer = Path(temporary) / "consumer"
            shutil.copytree(fixture / "src", consumer / "src")
            manifest = (fixture / "cjpm.toml").read_text()
            dependency = 'path = "../../.."'
            if manifest.count(dependency) != 1:
                raise ValueError("fixture must declare exactly one local chui dependency")
            (consumer / "cjpm.toml").write_text(manifest.replace(dependency, "path = " + json.dumps(str(root))))
            build = subprocess.run(["cjpm", "build", "-j", "1"], cwd=consumer,
                                   text=True, capture_output=True, timeout=900)
            result["buildExit"] = build.returncode
            result["buildLog"] = build.stdout + build.stderr
            if build.returncode:
                raise ValueError("external consumer build failed: " + result["buildLog"][-12000:])
            binary = consumer / "target/release/bin" / ("main.exe" if os.name == "nt" else "main")
            env = dict(os.environ)
            if sys.platform == "darwin":
                # Keep system image/font codecs independent of broad inherited loader paths.
                env["DYLD_LIBRARY_PATH"] = str(root / "sdl/.sdl3")
            run = subprocess.run([str(binary)], cwd=consumer, env=env,
                                 text=True, capture_output=True, timeout=60)
            result.update(runExit=run.returncode, runOutput=run.stdout, runError=run.stderr)
            if run.returncode:
                raise ValueError("external consumer runtime failed: " + run.stdout + run.stderr)
            result["scenes"] = verify_scenes(run.stdout)
            if "SCROLL_APPEARANCE_PASS cases=12" not in run.stdout.splitlines():
                raise ValueError("public scrollbar appearance verification did not finish")
            result["scrollAppearanceCasesVerified"] = 12
            if "EDITOR_VIEWPORT_PASS cases=3" not in run.stdout.splitlines():
                raise ValueError("public editor viewport verification did not finish")
            result["editorViewportCasesVerified"] = 3
            result.update(ok=True, externalPackage=True, scenesVerified=8,
                          frameworkImports="chui-only", physicalDeviceVerified=False)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        result["error"] = str(error)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    if not result["ok"]:
        raise SystemExit(result.get("error", "consumer verification failed"))
    print("External public API consumer passed: typed contracts and 8 theme/selection/expansion scenes")


if __name__ == "__main__":
    main()
