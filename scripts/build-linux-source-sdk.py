#!/usr/bin/env python3
"""Export an exact-revision Linux/glibc SDK candidate with explicit native inputs.

No downloads, host installs, implicit library discovery or consumer source edits.
This stage exports paired tools and audited native assets; CUIC Linux SDK
bootstrap/consumer execution remains a separate, currently closed capability.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


sdk = module("source_sdk", "build-source-sdk.py")
assembly = module("runtime_assembly", "assemble-linux-runtime.py")
elf = assembly.elf
TARGETS = {"aarch64": ("linux-arm64", "aarch64-unknown-linux-gnu", "AArch64"),
           "x86_64": ("linux-x86_64", "x86_64-unknown-linux-gnu", "Advanced Micro Devices X86-64")}
ALIASES = {"libSDL3.so": "libSDL3.so.0", "libSDL3_ttf.so": "libSDL3_ttf.so.0"}


def validate_profile(profile, architecture):
    if architecture not in TARGETS or profile["machine"] != TARGETS[architecture][2]:
        raise ValueError("native manifest does not match the Linux build host")
    names = [item["name"] for item in profile["libraries"]]
    if not set(ALIASES.values()).issubset(names) or set(ALIASES).intersection(names):
        raise ValueError("declare SDL loader libraries only; SDK generates exact linker aliases")
    if any(not name.startswith("lib") for name in names) or len(names) + len(ALIASES) >= elf.MAX_FILES:
        raise ValueError("SDK native names/count exceed the source-SDK contract")
    # Do not publish a build-machine's private sysroot in the portable profile.
    triple = "aarch64-linux-gnu" if architecture == "aarch64" else "x86_64-linux-gnu"
    allowed = {Path(value) for value in ("/lib", "/usr/lib", "/lib64", "/usr/lib64",
                                        "/lib/" + triple, "/usr/lib/" + triple)}
    if any(path not in allowed for path in profile["systemDirectories"]):
        raise ValueError("SDK requires standard target glibc directories, not a private sysroot")


def copy_native(output, profile):
    for name in ("native", "runtime/fonts", "runtime/licenses"):
        (output / name).mkdir(parents=True)
    inventory = []
    for item in profile["libraries"]:
        destination = output / "native" / item["name"]
        assembly.copy_record(item, destination)
        if elf.inspect(destination)["machine"] != profile["machine"]:
            raise ValueError("runtime library machine mismatch: " + item["name"])
        assembly.relocate(destination, "$ORIGIN")
        inventory.append({"name": item["name"], "inputSha256": item["sha256"],
                          "sha256": elf.digest(destination),
                          "licenses": assembly.notice_paths(item["licenses"], output)})
    # Regular copies, not symlinks: the immutable SDK ledger covers every byte.
    for alias, loader in ALIASES.items():
        shutil.copyfile(output / "native" / loader, output / "native" / alias)
    assembly.copy_record(profile["font"], output / "runtime/fonts/default.ttf")
    font_licenses = assembly.notice_paths(profile["font"]["licenses"], output)
    notices = assembly.notice_paths(profile["notices"], output)

    def record(relative):
        return {"source": "../" + relative, "sha256": elf.digest(output / relative)}

    portable = {"schema": assembly.SCHEMA, "machine": profile["machine"],
                "libraries": [{"name": item["name"], **record("native/" + item["name"]),
                               "licenses": [record(path) for path in item["licenses"]]} for item in inventory],
                "font": {**record("runtime/fonts/default.ttf"),
                         "licenses": [record(path) for path in font_licenses]},
                "notices": [record(path) for path in notices],
                "systemDirectories": [str(path) for path in profile["systemDirectories"]]}
    (output / "runtime/native-input.json").write_text(json.dumps(portable, indent=2) + "\n")
    return inventory


def verify_cli(output, binary, profile):
    if elf.inspect(binary)["machine"] != profile["machine"]:
        raise ValueError("CUIC executable machine differs from native manifest")
    assembly.relocate(binary, "$ORIGIN/../native")
    report = elf.audit(output, binary.relative_to(output), profile["systemDirectories"],
                       library_directory="native", additional_libraries=sorted(p.name for p in (output / "native").iterdir()))
    if report["findings"]:
        raise ValueError("SDK ELF closure failed: " + json.dumps(report["findings"]))
    return report


def manifest_projection(framework):
    path = framework / "sdl/cjpm.toml"
    source = path.read_text()
    if source.count('path = "./.sdl3"') != 2:
        raise ValueError("selected SDL manifest does not match the two-library SDK projection")
    path.write_text(source.replace('path = "./.sdl3"', 'path = "../../native"'))


def seal(output):
    entries = sorted(output.rglob("*"))
    if any(path.is_symlink() or not (path.is_file() or path.is_dir()) for path in entries):
        raise ValueError("SDK ledger cannot contain symlinks or special files")
    with (output / "SHA256SUMS").open("x") as ledger:
        for path in entries:
            if path.is_file():
                relative = path.relative_to(output).as_posix()
                if any(char in relative for char in "\n\r\\"):
                    raise ValueError("unsafe SDK ledger filename")
                ledger.write(f"{sdk.sha(path)}  {relative}\n")
    archive_path = output.with_name(output.name + ".tar.gz")
    with archive_path.open("xb") as destination:
        with tarfile.open(fileobj=destination, mode="w:gz") as archive:
            archive.add(output, arcname=output.name)
    return archive_path


def build(output, revision, manifest_path):
    architecture = platform.machine()
    if platform.system() != "Linux" or architecture not in TARGETS:
        raise ValueError("requires a native Linux aarch64 or x86_64 build host")
    target, triple, _ = TARGETS[architecture]
    if sdk.run("cjc", "--version").splitlines() != ["Cangjie Compiler: 1.1.3 (cjnative)", "Target: " + triple]:
        raise ValueError("requires the matching native Cangjie 1.1.3 compiler")
    profile = assembly.load_profile(manifest_path)
    validate_profile(profile, architecture)
    revision = sdk.run("git", "-C", sdk.ROOT, "rev-parse", revision + "^{commit}")
    output = output.absolute()
    if os.path.lexists(output) or os.path.lexists(output.with_name(output.name + ".tar.gz")):
        raise ValueError("SDK destination/archive already exists; no overwrite")
    output.mkdir(parents=True, exist_ok=False)
    output = output.resolve(strict=True)
    framework = output / "framework"
    sdk.export_revision(revision, sdk.SOURCE_ROOTS + ["scripts/assemble-linux-runtime.py",
                        "scripts/audit-linux-runtime.py", "contracts/canghui-linux-runtime-input-v0.schema.json"], framework)
    sdk.export_unicode_license(output, framework, revision)
    sdk.copy_framework_notices(output, framework)
    if sdk.sha(framework / "assets/fonts/HarmonyOS_Sans_SC.ttf") != profile["font"]["sha256"]:
        raise ValueError("profile font must match the exact source revision's default font")
    inventory = copy_native(output, profile)
    manifest_projection(framework)
    sdk.copy_licenses(Path(shutil.which("cjc")).resolve().parent.parent, output / "licenses/cangjie")
    reports = {}

    def verify(binary):
        reports[binary.name] = verify_cli(output, binary, profile)

    cli_version = sdk.build_cli_pair(output, revision, verify)
    floors = [report["numericGlibcFloor"] for report in reports.values()]
    if not all(floors):
        raise ValueError("missing ELF-derived glibc floor")
    minimum = max(floors, key=lambda value: tuple(map(int, value.split("."))))
    manifest = {"schema": "canghui.source-sdk/v2", "sourceCommit": revision, "cuicVersion": cli_version,
                "frameworkVersion": sdk.version(framework / "cjpm.toml"),
                "kitVersion": sdk.version(framework / "packages/kit/cjpm.toml"), "compilerVersion": "1.1.3",
                "target": target, "libc": "glibc", "minimumLibc": minimum,
                "nativeFiles": ",".join(sorted(p.name for p in (output / "native").iterdir()))}
    (framework / "canghui-sdk.env").write_text("".join(f"{key}={value}\n" for key, value in manifest.items()))
    (output / "native-inventory.json").write_text(json.dumps({"schema": "canghui.linux-sdk-inventory/v0",
        "inputManifestSha256": profile["sha256"], "libraries": inventory, "linkerAliases": ALIASES,
        "elfAudits": reports, "status": "exported-not-consumer-verified", "publisherSigning": False}, indent=2) + "\n")
    (output / "README.md").write_text(
        f'# CangHui Linux source SDK candidate\n\nCommit `{revision}`; `{target}`, measured glibc >= {minimum}.\n\n'
        'Paired CUIC tools, framework/Kit source, native inputs, fonts and license records.\n'
        'Requires separately installed Cangjie 1.1.3 for building apps. No framework checkout is required to inspect this candidate.\n'
        'Verify SHA256SUMS against a trusted receipt before executing tools; hashes are not publisher signatures.\n\n'
        '`bin/cuic sdk verify framework --json` inspects the payload and local build prerequisites.\n'
        'Linux SDK bootstrap/consumer execution is not implemented in this candidate. Do not advertise it as an app-delivery SDK.\n'
        '`runtime/native-input.json` is a relocatable native-input inventory; per-application dependency selection remains required.\n'
        'ELF metadata is not launch, symbol-availability, plugin, desktop-installation or redistribution compliance proof.\n')
    archive = seal(output)
    receipt = {"sdk": str(output), "archive": str(archive), "sha256": sdk.sha(archive),
               "sourceCommit": revision, "target": target, "minimumLibc": minimum,
               "status": "exported-not-consumer-verified"}
    print(json.dumps(receipt), flush=True)
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--revision", default="HEAD")
    parser.add_argument("--runtime-manifest", type=Path, required=True)
    args = parser.parse_args()
    try:
        build(args.output, args.revision, args.runtime_manifest)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, "Linux source SDK export failed: " + str(error) + "\n")
