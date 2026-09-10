#!/usr/bin/env python3
"""Assemble an explicitly declared, hash-pinned Linux runtime into a CUIC input tree.

No dependency downloads or implicit host-library discovery. License files are
carried verbatim; their presence is not a redistribution compliance certificate.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

spec = importlib.util.spec_from_file_location("linux_audit", Path(__file__).with_name("audit-linux-runtime.py"))
elf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(elf)
SCHEMA = "canghui.linux-runtime-input.v0"
RESERVED = ("bin", "lib", "run.sh", "runtime")


def record(value, base):
    if not isinstance(value, dict) or set(value) != {"source", "sha256"}:
        raise ValueError("file record requires source and sha256")
    if not isinstance(value["source"], str) or not value["source"]:
        raise ValueError("file record source must be a nonempty path")
    path = elf.regular(base / value["source"])
    expected = value["sha256"]
    if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise ValueError("file record requires lowercase SHA256")
    if elf.digest(path) != expected:
        raise ValueError("runtime input hash mismatch: " + path.name)
    return {"path": path, "sha256": expected}


def records(values, base):
    if not isinstance(values, list) or not 1 <= len(values) <= 64:
        raise ValueError("one to 64 notice records required")
    return [record(value, base) for value in values]


def load_profile(path):
    path = elf.regular(path)
    if path.stat().st_size > 2 * 1024 * 1024:
        raise ValueError("runtime input manifest exceeds limit")
    raw = path.read_bytes()
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate manifest key: " + key)
            result[key] = value
        return result
    data = json.loads(raw, object_pairs_hook=unique)
    if not isinstance(data, dict) or set(data) != {"schema", "machine", "libraries", "font", "notices", "systemDirectories"}:
        raise ValueError("runtime input manifest has missing or unknown fields")
    if data["schema"] != SCHEMA or not isinstance(data["machine"], str) or data["machine"] not in elf.LOADERS:
        raise ValueError("unsupported runtime input schema/machine")
    libraries = data["libraries"]
    if not isinstance(libraries, list) or not 1 <= len(libraries) < elf.MAX_FILES:
        raise ValueError("runtime input requires a bounded library list")
    result, names = [], set()
    for item in libraries:
        if not isinstance(item, dict) or set(item) != {"name", "source", "sha256", "licenses"}:
            raise ValueError("invalid library record")
        name = item["name"]
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.+\-]*\.so(?:\.[0-9]+)*", name):
            raise ValueError("invalid runtime library name")
        if name in names or name in elf.BASELINE:
            raise ValueError("duplicate or system-baseline library: " + name)
        names.add(name)
        result.append({"name": name, **record({key: item[key] for key in ("source", "sha256")}, path.parent),
                       "licenses": records(item["licenses"], path.parent)})
    font = data["font"]
    if not isinstance(font, dict) or set(font) != {"source", "sha256", "licenses"}:
        raise ValueError("invalid font record")
    font_record = record({key: font[key] for key in ("source", "sha256")}, path.parent)
    font_record["licenses"] = records(font["licenses"], path.parent)
    system = data["systemDirectories"]
    if not isinstance(system, list) or not 1 <= len(system) <= 16 or any(not isinstance(value, str) for value in system):
        raise ValueError("explicit target system directories required")
    return {"machine": data["machine"], "libraries": result, "font": font_record,
            "notices": records(data["notices"], path.parent),
            "systemDirectories": [(path.parent / value).resolve(strict=True) for value in system],
            "sha256": hashlib.sha256(raw).hexdigest()}


def copy_record(value, target):
    shutil.copyfile(value["path"], target)
    if elf.digest(target) != value["sha256"]:
        raise ValueError("runtime input changed during copy")


def notice_paths(values, stage):
    result = []
    for value in values:
        suffix = value["path"].suffix.lower()
        if not re.fullmatch(r"\.[a-z0-9]{1,8}", suffix):
            suffix = ".notice"
        relative = "runtime/licenses/" + value["sha256"] + suffix
        target = stage / relative
        if not target.exists():
            copy_record(value, target)
        result.append(relative)
    return result


def relocate(path, value):
    subprocess.run(["patchelf", "--set-rpath", value, str(path)], check=True, timeout=30)


def launcher(identifier):
    if (not re.fullmatch(r"[A-Za-z0-9_.-]+", identifier) or not re.search(r"[A-Za-z0-9]", identifier)
            or identifier.startswith(".") or identifier.endswith(".") or ".." in identifier):
        raise ValueError("invalid application identifier")
    return ("#!/bin/sh\nset -eu\n"
            "case $0 in */*) script=$0 ;; *) script=$(command -v -- \"$0\") ;; esac\n"
            'bundle_root=$(CDPATH= cd -- "${script%/*}/.." && pwd)\n'
            'export CANGHUI_HARMONYOS_SANS="$bundle_root/runtime/fonts/default.ttf"\n'
            f"export SDL_APP_ID='{identifier}'\n"
            f'exec "$bundle_root/bin/{identifier}.bin" "$@"\n')


def select_libraries(binary_metadata, profile, reader=elf.inspect):
    """Select only declared DT_NEEDED closure; never discover ambient libraries."""
    by_name = {item["name"]: item for item in profile["libraries"]}
    selected, pending = set(), list(binary_metadata["needed"])
    while pending:
        name = pending.pop(0)
        if name in elf.BASELINE or name in selected:
            continue
        if name not in by_name:
            raise ValueError("application dependency is not declared by SDK: " + name)
        selected.add(name)
        metadata = reader(by_name[name]["path"])
        if metadata["sha256"] != by_name[name]["sha256"] or metadata["machine"] != profile["machine"]:
            raise ValueError("SDK dependency changed or has wrong architecture: " + name)
        pending.extend(metadata["needed"])
    return [item for item in profile["libraries"] if item["name"] in selected]


def assemble(output, binary, profile_path, identifier, *, select_used=False):
    wrapper = launcher(identifier)
    output = Path(output).resolve(strict=True)
    if not output.is_dir():
        raise ValueError("CUIC output must be an existing directory")
    for name in RESERVED:
        if os.path.lexists(output / name):
            raise ValueError("runtime output already exists: " + name)
    profile = load_profile(profile_path)
    binary = elf.regular(binary)
    binary_metadata = elf.inspect(binary)
    if binary_metadata["machine"] != profile["machine"]:
        raise ValueError("application and runtime manifest machines differ")
    libraries = select_libraries(binary_metadata, profile) if select_used else profile["libraries"]
    with tempfile.TemporaryDirectory(prefix=".runtime-stage-", dir=output) as temporary:
        stage = Path(temporary)
        for name in ("bin", "lib", "runtime/fonts", "runtime/licenses"):
            (stage / name).mkdir(parents=True)
        native_name = "bin/" + identifier + ".bin"
        copy_record({"path": binary, "sha256": binary_metadata["sha256"]}, stage / native_name)
        os.chmod(stage / native_name, 0o755)
        relocate(stage / native_name, "$ORIGIN/../lib")
        inventory = []
        for item in libraries:
            destination = stage / "lib" / item["name"]
            copy_record(item, destination)
            if elf.inspect(destination)["machine"] != profile["machine"]:
                raise ValueError("runtime library machine mismatch: " + item["name"])
            relocate(destination, "$ORIGIN")
            inventory.append({"name": item["name"], "inputSha256": item["sha256"],
                              "sha256": elf.digest(destination), "licenses": notice_paths(item["licenses"], stage)})
        copy_record(profile["font"], stage / "runtime/fonts/default.ttf")
        font_licenses = notice_paths(profile["font"]["licenses"], stage)
        notices = notice_paths(profile["notices"], stage)
        (stage / "bin" / identifier).write_text(wrapper, encoding="utf-8")
        (stage / "bin" / identifier).chmod(0o755)
        (stage / "run.sh").write_text('#!/bin/sh\nset -eu\nroot=$(CDPATH= cd -- "${0%/*}" && pwd)\n'
                                      f'exec "$root/bin/{identifier}" "$@"\n', encoding="utf-8")
        (stage / "run.sh").chmod(0o755)
        report = elf.audit(stage, native_name, profile["systemDirectories"])
        if report["findings"]:
            raise ValueError("assembled runtime failed ELF audit: " + json.dumps(report["findings"]))
        receipt = {"schema": "canghui.linux-runtime-bundle.v0", "status": "assembled-not-launched",
                   "inputManifestSha256": profile["sha256"], "applicationInputSha256": binary_metadata["sha256"],
                   "identifier": identifier, "libraries": inventory, "fontSha256": profile["font"]["sha256"],
                   "dependencySelection": "declared-transitive-closure" if select_used else "all-declared-inputs",
                   "fontLicenses": font_licenses, "notices": notices, "elfAudit": report,
                   "limitations": ["license-records-carried-not-legally-reviewed", "dlopen-plugins-not-verified",
                                   "launch-and-desktop-installation-not-verified", "unsigned"]}
        (stage / "runtime/receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        # CUIC exclusively owns its newly created output; never replace an existing runtime.
        for name in RESERVED:
            if os.path.lexists(output / name):
                raise ValueError("runtime output appeared during assembly: " + name)
        for name in RESERVED:
            (stage / name).rename(output / name)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--identifier", required=True)
    parser.add_argument("--select-used-libraries", action="store_true",
                        help="select only DT_NEEDED closure from the explicit manifest (SDK consumption)")
    args = parser.parse_args()
    try:
        assemble(args.output, args.binary, args.manifest, args.identifier, select_used=args.select_used_libraries)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, "Linux runtime assembly failed: " + str(error) + "\n")


if __name__ == "__main__":
    main()
