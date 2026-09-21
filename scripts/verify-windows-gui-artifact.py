#!/usr/bin/env python3
"""Replay CUIC's Windows GUI packaging against a caller-supplied real PE.

Never launches or modifies the input. This checks packaging, not Windows runtime.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


def field16(data, offset):
    return struct.unpack_from("<H", data, offset)[0]


def field32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def check_image(original, result, subsystem):
    pe = field32(original, 0x3C)
    optional = pe + 24
    assert len(result) == len(original)
    assert field16(result, optional + 68) == subsystem
    assert field32(result, optional + 16) == field32(original, optional + 16)
    permitted = set(range(optional + 64, optional + 70))
    assert all(a == b or i in permitted for i, (a, b) in enumerate(zip(original, result)))
    scratch = bytearray(result)
    scratch[optional + 64:optional + 68] = b"\0" * 4
    if len(scratch) % 2:
        scratch.append(0)
    total = sum(item[0] for item in struct.iter_unpack("<H", scratch))
    while total >> 16:
        total = (total & 65535) + (total >> 16)
    assert field32(result, optional + 64) == total + len(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cuic", type=Path, required=True)
    parser.add_argument("--exe", type=Path, required=True)
    args = parser.parse_args()
    executable = args.exe.resolve(strict=True)
    cuic = args.cuic.resolve(strict=True)
    original = executable.read_bytes()
    root = Path(tempfile.mkdtemp(prefix="chui-windows-gui-"))
    (root / "cjpm.toml").write_text('[package]\nname = "gui_probe"\nversion = "1.0.0"\noutput-type = "executable"\n')
    (root / "canghui.toml").write_text('[application]\nname = "Probe"\nidentifier = "dev.chui.probe"\nversion = "1.0.0"\n')
    shutil.copyfile(executable, root / "input.exe")
    base = [str(cuic), "package", "build", "windows", str(root)]

    def run(extra, expected=0):
        result = subprocess.run(base + extra + ["--json"], capture_output=True, text=True)
        assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
        return result

    for name, subsystem, extra in [("gui", 2, []), ("console", 3, ["--console"])]:
        response = run(["--executable", "input.exe", "--output", name] + extra)
        receipt = json.loads(response.stdout)
        assert receipt["executableIncluded"] and not receipt["signed"]
        assert receipt["hostReplay"] == "supplied-pe-validated-not-launched"
        assert receipt["artifactKind"] == f"windows-unsigned-{name}-application"
        image = root / name / "Probe.exe"
        check_image(original, image.read_bytes(), subsystem)
        before = hashlib.sha256(image.read_bytes()).hexdigest()
        run(["--executable", "input.exe", "--output", name], 1)
        assert hashlib.sha256(image.read_bytes()).hexdigest() == before
        assert not (root / (name + ".cuic-lease")).exists()

    optional = field32(original, 0x3C) + 24
    directories = optional + (112 if field16(original, optional) == 0x20B else 96)
    signed = bytearray(original)
    struct.pack_into("<II", signed, directories + 32, len(signed), 8)
    signed.extend(b"\0" * 8)
    (root / "signed.exe").write_bytes(signed)
    run(["--executable", "signed.exe", "--output", "signed-output"], 1)
    assert not (root / "signed-output").exists()
    assert executable.read_bytes() == original == (root / "input.exe").read_bytes()
    print(json.dumps({"result": "pass", "proof": "real-pe-structure-not-windows-launch",
        "inputSha256": hashlib.sha256(original).hexdigest(), "bytes": len(original),
        "originalEntryRva": field32(original, optional + 16), "output": str(root)}, indent=2))


if __name__ == "__main__":
    main()
