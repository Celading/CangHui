#!/usr/bin/env python3
"""Export one opt-in, application-owned Kit copy. Never updates an existing copy."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tomllib

ROOT = Path(__file__).resolve().parents[1]
KITS = {"kit": "canghui_kit", "style-liquid-glass": "canghui_style_liquid_glass"}
NOTICES = ("LICENSE", "NOTICE", "THIRD_PARTY_NOTICES.md")


def regular(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError("source entries must be regular files")
    return path.read_bytes()


def export(kit, framework, output, source=ROOT):
    source = Path(source).resolve()
    framework = Path(framework).resolve(strict=True)
    output = Path(output).absolute()
    parent = output.parent.resolve(strict=True)
    output = parent / output.name
    if output.exists() or output.is_symlink():
        raise ValueError("output exists; export upgrades to a new directory and review your changes")
    if output.is_relative_to(source) or output.is_relative_to(framework):
        raise ValueError("output must be outside framework/source trees")
    package = source / "packages" / kit
    if package.is_symlink() or (package / "src").is_symlink():
        raise ValueError("package/source directory must not be a symlink")
    package_manifest = tomllib.loads(regular(package / "cjpm.toml").decode())
    metadata = package_manifest["package"]
    if set(package_manifest) != {"package", "dependencies"} or set(package_manifest["dependencies"]) != {"chui"}:
        raise ValueError("package dependency/build closure changed; review before exporting")
    if set(p.name for p in package.iterdir()) - {"src", "README.md", "cjpm.toml", "cjpm.lock", "target"}:
        raise ValueError("package resources changed; review before exporting")
    dependency = tomllib.loads(regular(framework / "cjpm.toml").decode())["package"]
    if metadata["name"] != KITS[kit] or dependency["name"] != "chui":
        raise ValueError("package identity mismatch")
    # Source compatibility declaration, not a compiler/ABI or native-host certification.
    version = dependency["version"].split(".")
    if len(version) != 3 or not all(x.isdecimal() for x in version) or tuple(map(int, version)) < (0, 17, 0):
        raise ValueError("these recipes require chui >= 0.17.0; verify the selected compiler/host separately")
    entries = {name: regular(source / name) for name in NOTICES}
    entries["README.md"] = regular(package / "README.md")
    for path in sorted((package / "src").iterdir()):
        if path.is_symlink() or not path.is_file() or path.suffix != ".cj":
            raise ValueError("unexpected source entry; update the exporter only after reviewing its closure")
        entries["src/" + path.name] = regular(path)
    if not any(name.startswith("src/") for name in entries):
        raise ValueError("empty source package")
    manifest = "[package]\n" + "".join(
        f"{key} = {json.dumps(metadata[key], ensure_ascii=False)}\n"
        for key in ("cjc-version", "name", "version", "output-type", "description", "license")
    ) + "\n[dependencies]\nchui = { path = " + json.dumps(str(framework), ensure_ascii=False) + " }\n"
    entries["cjpm.toml"] = manifest.encode()
    entries["OWNED-SOURCE.md"] = (
        "# Application-owned Kit source\n\n"
        "This copy belongs to your application. Keep local edits in your own version control.\n"
        "Upgrade into another directory; compare upstream file hashes and perform a three-way merge.\n"
        "Never replace this tree automatically. No core input, focus or renderer source is copied.\n"
        "The generated chui path is local build configuration; change it deliberately for distribution.\n"
        "README links referring to the original monorepo are upstream navigation, not copied resources.\n"
    ).encode()
    try:
        commit = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
        dirty = bool(subprocess.check_output(["git", "-C", str(source), "status", "--porcelain", "--",
                                             "packages/" + kit, *NOTICES], text=True).strip())
    except (OSError, subprocess.CalledProcessError):
        commit, dirty = None, True
    receipt = {
        "schema": "canghui.owned-kit-source.v1", "package": metadata["name"],
        "version": metadata["version"], "sourceRevision": commit, "sourceDirty": dirty,
        "license": metadata["license"], "minimumChui": "0.17.0", "selectedChuiVersion": dependency["version"], "resources": [],
        "nativeDependencies": [], "dependencies": ["chui"],
        "compatibility": "common-source; compiler and native-host verification required",
        "updatePolicy": "new-directory-only; application owns merge",
        "sourceFiles": {p: hashlib.sha256(data).hexdigest() for p, data in entries.items()
                        if p.startswith("src/")},
        "files": {p: hashlib.sha256(data).hexdigest() for p, data in entries.items()},
    }
    entries["kit-source.json"] = (json.dumps(receipt, indent=2, ensure_ascii=False) + "\n").encode()
    # Exclusive creation is the overwrite guard. On storage failure keep the partial directory
    # for inspection; never recursively remove a path which another actor might have populated.
    output.mkdir()
    (output / "src").mkdir()
    for name, data in entries.items():
        with (output / name).open("xb") as stream:
            stream.write(data)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kit", required=True, choices=KITS)
    parser.add_argument("--chui", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = export(args.kit, args.chui, args.output)
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, f"Kit export refused: {error}\n")
    print(json.dumps({"package": result["package"], "files": len(result["files"]),
                      "sourceDirty": result["sourceDirty"], "output": str(args.output)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
