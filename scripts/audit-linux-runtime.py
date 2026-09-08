#!/usr/bin/env python3
"""Inspect an ELF64/glibc application bundle without executing any payload.

Explicit inputs only: no ldd, ambient loader paths, downloads, or bundle mutation.
Passing proves dependency metadata, not plugin availability, licensing or launch.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile

BASELINE = {"libc.so.6", "libm.so.6", "libpthread.so.0", "libdl.so.2", "librt.so.1",
            "ld-linux-aarch64.so.1", "ld-linux-x86-64.so.2"}
LOADERS = {"AArch64": "/lib/ld-linux-aarch64.so.1",
           "Advanced Micro Devices X86-64": "/lib64/ld-linux-x86-64.so.2"}
MAX_FILES = 128


def regular(path):
    path = Path(path).resolve(strict=True)
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= 512 * 1024 * 1024:
        raise ValueError("not a bounded regular ELF file: " + str(path))
    return path


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def parse_metadata(text):
    def field(name):
        found = re.search(r"^\s*" + re.escape(name) + r":\s*(.*?)\s*$", text, re.M)
        if not found:
            raise ValueError("missing ELF header field: " + name)
        return found[1]
    if field("Class") != "ELF64" or "little endian" not in field("Data"):
        raise ValueError("only little-endian ELF64 is supported")
    kind = field("Type").split()[0]
    if kind not in ("EXEC", "DYN"):
        raise ValueError("not an ELF executable/shared object")
    machine = field("Machine")
    if machine not in LOADERS:
        raise ValueError("unsupported ELF machine: " + machine)
    interpreter = re.findall(r"\[Requesting program interpreter: ([^\]]+)\]", text)
    if len(interpreter) > 1:
        raise ValueError("multiple ELF interpreters")
    needed = re.findall(r"\(NEEDED\)\s+Shared library: \[(.*)\]\s*$", text, re.M)
    if len(needed) != len(re.findall(r"\(NEEDED\)", text)) or any(
            not re.fullmatch(r"[A-Za-z0-9_.+\-]+", name) for name in needed):
        raise ValueError("unsafe DT_NEEDED name")
    search = re.findall(r"\((?:RPATH|RUNPATH)\)\s+Library (?:rpath|runpath): \[(.*)\]\s*$", text, re.M)
    if len(search) != len(re.findall(r"\((?:RPATH|RUNPATH)\)", text)):
        raise ValueError("malformed ELF search path")
    needs = re.search(r"Version needs section.*?(?=\nVersion .* section|\Z)", text, re.S)
    versions = sorted(set(re.findall(r"Name: (GLIBC_[A-Za-z0-9_.]+)", needs[0] if needs else "")))
    return {"machine": machine, "type": kind, "interpreter": interpreter[0] if interpreter else None,
            "needed": needed, "searchPaths": [entry for group in search for entry in group.split(":")],
            "requiredGlibcVersions": versions}


def inspect(path):
    path = regular(path)
    before = digest(path)
    # GNU readelf is a metadata reader; do not replace it with a payload loader.
    with tempfile.TemporaryFile() as output:
        result = subprocess.run(["readelf", "--wide", "--file-header", "--program-headers",
                                 "--dynamic", "--version-info", str(path)],
                                stdout=output, stderr=output, timeout=30,
                                env={**os.environ, "LC_ALL": "C"})
        if output.tell() > 8 * 1024 * 1024:
            raise ValueError("ELF metadata exceeds limit")
        output.seek(0)
        text = output.read().decode("utf-8", errors="strict")
    if result.returncode:
        raise ValueError("readelf rejected: " + str(path))
    if digest(path) != before:
        raise ValueError("ELF changed while auditing: " + str(path))
    return {**parse_metadata(text), "sha256": before}


def safe_search_path(value, owner, root):
    if value == "$ORIGIN":
        suffix = "."
    elif value.startswith("$ORIGIN/"):
        suffix = value[len("$ORIGIN/"):]
    else:
        return False
    if "$" in suffix or "\\" in suffix:
        return False
    return (owner.parent / suffix).resolve().is_relative_to(root)


def audit(root, executable, system_dirs, reader=inspect):
    root = Path(root).resolve(strict=True)
    binary = regular(root / executable)
    if not binary.is_relative_to(root):
        raise ValueError("executable escapes bundle")
    system_dirs = [Path(path).resolve(strict=True) for path in system_dirs]
    if any(not path.is_dir() or path.is_relative_to(root) for path in system_dirs):
        raise ValueError("system directories must be outside the bundle")
    library_root = root / "lib"
    findings, files, supplied, seen = [], [], {}, set()
    machine = reader(binary)["machine"]
    queue = [binary]
    while queue:
        path = queue.pop(0)
        if path in seen:
            continue
        if len(seen) >= MAX_FILES:
            raise ValueError("ELF closure exceeds file limit")
        seen.add(path)
        entry = reader(path)
        name = str(path.relative_to(root))
        files.append({"path": name, **entry})
        if entry["machine"] != machine:
            findings.append({"code": "architecture-mismatch", "path": name})
        if path == binary and entry["interpreter"] != LOADERS[machine]:
            findings.append({"code": "unsupported-interpreter", "path": name})
        for value in entry["searchPaths"]:
            if not safe_search_path(value, path, root):
                findings.append({"code": "nonrelocatable-search-path", "path": name, "value": value})
        dependencies = list(entry["needed"])
        if path == binary and entry["interpreter"]:
            dependencies.append(Path(entry["interpreter"]).name)
        for dependency in dict.fromkeys(dependencies):
            local = library_root / dependency
            if local.exists() or local.is_symlink():
                candidate = regular(local)
                if not candidate.is_relative_to(root):
                    raise ValueError("library escapes bundle: " + dependency)
                if dependency in BASELINE:
                    findings.append({"code": "bundled-system-baseline", "path": name, "dependency": dependency})
                queue.append(candidate)
            elif dependency in BASELINE:
                candidates = {regular(folder / dependency) for folder in system_dirs
                              if (folder / dependency).exists() or (folder / dependency).is_symlink()}
                if len(candidates) != 1:
                    findings.append({"code": "unresolved-system-baseline", "path": name, "dependency": dependency})
                elif dependency not in supplied:
                    candidate = candidates.pop()
                    metadata = reader(candidate)
                    supplied[dependency] = {"path": str(candidate), "sha256": metadata["sha256"]}
                    if metadata["machine"] != machine:
                        findings.append({"code": "system-architecture-mismatch", "dependency": dependency})
            else:
                findings.append({"code": "unbundled-dependency", "path": name, "dependency": dependency})
    if library_root.exists():
        for path in library_root.iterdir():
            if path.resolve() not in seen:
                findings.append({"code": "uninspected-library-entry", "path": str(path.relative_to(root))})
    tags = sorted({tag for item in files for tag in item["requiredGlibcVersions"]})
    numeric = [tuple(map(int, tag[6:].split("."))) for tag in tags if re.fullmatch(r"GLIBC_\d+(?:\.\d+)+", tag)]
    return {"schema": "canghui.linux-runtime-audit.v0", "status": "needs-repair" if findings else "dependency-metadata-ready",
            "machine": machine, "files": files, "systemProvided": supplied, "findings": findings,
            "numericGlibcFloor": ".".join(map(str, max(numeric))) if numeric else None,
            "requiredGlibcVersions": tags,
            "notVerified": ["runtime-launch", "dlopen-plugins", "font-assets", "licenses-and-redistribution",
                            "system-symbol-version-availability", "kernel-and-cpu-floor", "desktop-installation"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--executable", default="bin/main")
    parser.add_argument("--system-dir", action="append", default=[])
    args = parser.parse_args()
    try:
        report = audit(args.bundle, args.executable, args.system_dir)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps({"schema": "canghui.linux-runtime-audit.v0", "status": "audit-error", "error": str(error)}))
        return 2
    print(json.dumps(report, indent=2))
    return 1 if report["findings"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
