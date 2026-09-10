#!/usr/bin/env python3
"""Replay init -> locked dependency -> exact debug target -> welcome action.

Use a debug CUIC. With no --framework this exercises the published default pin;
with --framework it exercises a local checkout or a matching immutable SDK.
Output is retained for inspection. This is a host regression, not clean-host proof.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cuic", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--framework", type=Path)
    args = parser.parse_args()
    cli = args.cuic.resolve(strict=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        parser.error("--output must be empty; prior evidence is not overwritten")
    app = output / "Hello"
    target = output / "isolated-target"
    env = dict(os.environ, CUIC_TARGET_DIR=str(target))

    def run(name: str, *command: str) -> str:
        result = subprocess.run([str(cli), *command], env=env, text=True,
                                capture_output=True, timeout=600)
        (output / f"{name}.stdout").write_text(result.stdout)
        (output / f"{name}.stderr").write_text(result.stderr)
        if result.returncode:
            raise RuntimeError(f"{name} exited {result.returncode}; see {output}")
        return result.stdout

    init = ["init", str(app), "--name", "welcome_replay"]
    if args.framework:
        init += ["--canghui-path", str(args.framework.resolve(strict=True))]
    run("init", *init)
    if not args.framework:
        run("dependency-update", "dependency", "update", str(app))
    document = json.loads(run("action", "probe", "run", str(app), "welcome.main",
                              "--events", "focus welcome.ready\nkey Enter\ndraw", "--json"))
    assert document["ok"] is True, document.get("errors")
    labels = [node.get("properties", {}).get("label")
              for node in document["frames"][-1]["nodes"]]
    assert "CangHui 已准备好" in labels, "Enter did not update the shared welcome state"
    assert not (app / "target").exists(), "runtime rebuilt an unintended default target"
    assert not Path(str(target) + ".cuic-lease").exists(), "probe leaked its target lease"
    assert (target / "debug/bin/main").exists() or (target / "debug/bin/main.exe").exists()
    print("Generated consumer passed: locked/local dependency, exact target, focus and Enter state update")


if __name__ == "__main__":
    main()
