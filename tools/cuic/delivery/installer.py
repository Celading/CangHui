#!/usr/bin/env python3
"""Thin, offline Windows EXE packaging with the private canghui-package engine."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import tomllib

SCHEMA = "chui.installer-engine.v1"
MAX_BYTES = 1024 * 1024 * 1024
MAX_FILES = 10000
RESERVED = {"CON", "PRN", "AUX", "NUL", *(f"COM{i}" for i in range(10)),
            *(f"LPT{i}" for i in range(10))}


class DeliveryError(ValueError):
    pass


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def relative(value):
    if not isinstance(value, str) or not value or len(value) > 180:
        raise DeliveryError("invalid relative path")
    parts = value.split("/")
    for part in parts:
        if (not part or part in (".", "..") or part[-1] in " ."
                or any(ord(c) < 32 or c in '<>:"\\|?*$' for c in part)
                or part.split(".")[0].upper() in RESERVED):
            raise DeliveryError(f"unsafe Windows path: {value!r}")
    return Path(*parts)


def no_links(path):
    for item in (path, *path.parents):
        if item.is_symlink():
            raise DeliveryError(f"symlink is not supported: {item}")
        if item.exists() and getattr(item.lstat(), "st_file_attributes", 0) & 0x400:
            raise DeliveryError(f"Windows reparse point is not supported: {item}")


def inventory(root):
    no_links(root)
    if not root.is_dir():
        raise DeliveryError("input directory is missing")
    files, names, size = {}, set(), 0
    for directory, dirs, leaves in os.walk(root, followlinks=False):
        for name in sorted(dirs + leaves):
            item = Path(directory) / name
            no_links(item)
            rel = item.relative_to(root).as_posix()
            relative(rel)
            key = rel.casefold()
            if key in names:
                raise DeliveryError("case-insensitive path collision")
            names.add(key)
            if len(names) > MAX_FILES:
                raise DeliveryError("input exceeds 10000 directory entries")
            mode = item.lstat().st_mode
            if stat.S_ISDIR(mode):
                continue
            if not stat.S_ISREG(mode):
                raise DeliveryError("links and special files are not supported")
            size += item.stat().st_size
            if size > MAX_BYTES or len(files) >= MAX_FILES:
                raise DeliveryError("input exceeds 1 GiB / 10000 files")
            files[rel] = digest(item)
    return dict(sorted(files.items()))


def host_tag():
    arch = {"aarch64": "arm64", "AMD64": "x86_64"}.get(platform.machine(), platform.machine())
    return f"{sys.platform}-{arch}"


def check_engine(root):
    files = inventory(root)
    if "engine.json" not in files:
        raise DeliveryError("private engine.json missing; use a delivery bundle or HapCLI-provided engine pack")
    if (root / "engine.json").stat().st_size > 4 * 1024 * 1024:
        raise DeliveryError("engine manifest exceeds 4 MiB")
    info = json.loads((root / "engine.json").read_text(encoding="utf-8"))
    if not isinstance(info, dict):
        raise DeliveryError("engine manifest must be an object")
    if info.get("schema") != SCHEMA or info.get("host") != host_tag():
        raise DeliveryError("engine schema/host mismatch")
    if info.get("engine", "canghui-package") != "canghui-package" or info.get("backend", "NSIS") != "NSIS":
        raise DeliveryError("engine identity/backend mismatch")
    expected = info.get("files")
    if not isinstance(expected, dict) or expected != {k: v for k, v in files.items() if k != "engine.json"}:
        raise DeliveryError("engine file inventory/hash mismatch")
    if not isinstance(info.get("version"), str) or not re.fullmatch(r"3\.\d+(?:\.\d+)?", info["version"]):
        raise DeliveryError("unsupported canghui-package NSIS backend version")
    exe = "makensis.exe" if sys.platform == "win32" else "makensis"
    for name in (exe, "COPYING", "Stubs/zlib-x86-unicode"):
        if name not in files:
            raise DeliveryError(f"engine file missing: {name}")
    if "honorFormat" in info:
        if info["honorFormat"] != "chui-honor-v1":
            raise DeliveryError("unsupported Honor format")
        for name in (f"honor/{exe}", "honor/COPYING", "honor/Stubs/zlib-x86-unicode"):
            if name not in files:
                raise DeliveryError(f"incomplete Honor profile: {name}")
    return info, root / exe


def quote(value):
    # No preprocessor or runtime variable expansion from manifest text.
    if not isinstance(value, str) or not value or len(value) > 128 or any(ord(c) < 32 for c in value):
        raise DeliveryError("identity must be short nonempty single-line text")
    return '"' + value.replace('$', '$$').replace('"', '$\\"') + '"'


def identity(project):
    source = project / "canghui.toml"
    no_links(source)
    if source.stat().st_size > 65536:
        raise DeliveryError("application manifest exceeds 64 KiB")
    app = tomllib.loads(source.read_text(encoding="utf-8")).get("application", {})
    if not isinstance(app, dict):
        raise DeliveryError("application must be a TOML table")
    for key in ("name", "identifier", "version"):
        quote(app.get(key))
    app = {key: app.get(key, "") for key in ("name", "identifier", "version", "publisher")}
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*(?:[.-][A-Za-z0-9]+)+", app["identifier"]):
        raise DeliveryError("application identifier must be a dotted identifier")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?", app["version"]):
        raise DeliveryError("application version must be semantic version text")
    if not isinstance(app["publisher"], str):
        raise DeliveryError("publisher must be text")
    if app["publisher"]:
        quote(app["publisher"])
    return app


def pe_machine(path):
    with path.open("rb") as stream:
        header = stream.read(64)
        if len(header) != 64 or header[:2] != b"MZ":
            raise DeliveryError("entry must be a Windows PE executable")
        offset = struct.unpack_from("<I", header, 60)[0]
        if offset < 64 or offset > path.stat().st_size - 26:
            raise DeliveryError("invalid PE header offset")
        stream.seek(offset)
        pe = stream.read(26)
    machine = struct.unpack_from("<H", pe, 4)[0]
    flags = struct.unpack_from("<H", pe, 22)[0]
    if pe[:4] != b"PE\0\0" or machine not in (0x14c, 0x8664) or flags & 0x2000 or not flags & 2:
        raise DeliveryError("entry must be an x86/x64 PE executable, not a DLL")
    return "x64" if machine == 0x8664 else "x86"


def render(app, files, entry, mode, honor):
    ident, version = app["identifier"], app["version"]
    dest = f"$LOCALAPPDATA\\Programs\\{ident}\\{version}"
    key = f"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{ident}-{version}"
    winentry = entry.replace("/", "\\")
    lines = ['Unicode true', 'RequestExecutionLevel user', 'CRCCheck force',
             'SetCompressor zlib', 'Name ' + quote(app["name"]), 'OutFile "package.exe"',
             'ShowInstDetails show', 'SetOverwrite off']
    if honor:
        lines += ['BrandingText "CangHui - Honor System"']
    if mode == "install":
        lines += ['Page instfiles', 'UninstPage uninstConfirm', 'UninstPage instfiles',
                  'Function .onInit', f'  StrCpy $INSTDIR "{dest}"',
                  # Same-user duplicate installer guard; no elevation or global mutex.
                  f'  System::Call \'kernel32::CreateMutexW(p 0, i 0, w "Local\\{ident}-{version}-install") p .r0 ?e\'',
                  '  Pop $1', '  StrCmp $1 183 busy', '  StrCmp $0 0 busy',
                  '  IfFileExists "$INSTDIR" busy confirm', 'busy:',
                  '  MessageBox MB_OK|MB_ICONSTOP "This version is already present or installing. Uninstall it first." /SD IDOK',
                  '  SetErrorLevel 2', '  Quit', 'confirm:',
                  '  MessageBox MB_YESNO|MB_ICONQUESTION "Install for the current user?" /SD IDNO IDYES ready',
                  '  SetErrorLevel 1', '  Quit', 'ready:', 'FunctionEnd']
    else:
        lines += ['SilentInstall silent']
    lines += ['Section "Application"', '  SetShellVarContext current', '  ClearErrors']
    if mode == "portable":
        lines += ['  InitPluginsDir', '  StrCpy $INSTDIR "$PLUGINSDIR\\app"']
    for rel in files:
        parent = str(Path(rel).parent).replace("/", "\\")
        suffix = "" if parent == "." else "\\" + parent
        lines += [f'  SetOutPath "$INSTDIR{suffix}"', f'  File "payload/{rel}"']
    lines += ['  IfErrors failed']
    if mode == "portable":
        lines += ['  SetOutPath "$INSTDIR"', f'  ExecWait \'"$INSTDIR\\{winentry}"\' $0',
                  '  IfErrors failed', '  SetOutPath "$TEMP"', '  SetErrorLevel $0', '  Goto done']
    else:
        lines += ['  WriteUninstaller "$INSTDIR\\Uninstall.exe"', '  IfErrors failed',
                  f'  CreateShortCut "$SMPROGRAMS\\{ident}-{version}.lnk" "$INSTDIR\\{winentry}"',
                  f'  WriteRegStr HKCU "{key}" "DisplayName" {quote(app["name"])}',
                  f'  WriteRegStr HKCU "{key}" "DisplayVersion" {quote(version)}',
                  f'  WriteRegStr HKCU "{key}" "UninstallString" \'"$INSTDIR\\Uninstall.exe"\'',
                  f'  WriteRegStr HKCU "{key}" "InstallLocation" "$INSTDIR"',
                  '  IfErrors failed', '  SetErrorLevel 0', '  Goto done']
    lines += ['failed:', '  SetErrorLevel 3', '  SetOutPath "$TEMP"',
              '  Abort "Application extraction/launch/registration failed; inspect partial output before retrying."',
              'done:', 'SectionEnd']
    if mode == "install":
        lines += ['Section "Uninstall"', '  SetShellVarContext current',
                  f'  StrCmp $INSTDIR "{dest}" safe', '  SetErrorLevel 4',
                  '  Abort "Unexpected uninstall location."', 'safe:', '  ClearErrors']
        for rel in files:
            lines.append('  Delete "$INSTDIR\\' + rel.replace('/', '\\') + '"')
        # Preserve unknown/user-created files: never RMDir /r in installed trees.
        lines += ['  IfErrors unfailed', '  Delete "$INSTDIR\\Uninstall.exe"',
                  '  IfErrors unfailed', f'  Delete "$SMPROGRAMS\\{ident}-{version}.lnk"',
                  f'  DeleteRegKey HKCU "{key}"']
        dirs = {p.as_posix() for f in files for p in Path(f).parents if p != Path(".")}
        for rel in sorted(dirs, key=lambda v: (-v.count('/'), v)):
            lines.append('  RMDir "$INSTDIR\\' + rel.replace('/', '\\') + '"')
        lines += ['  RMDir "$INSTDIR"', '  SetErrorLevel 0', '  Goto undoned',
                  'unfailed:', '  SetErrorLevel 5', '  Abort "Some application files are in use. Close the application and retry."',
                  'undoned:', 'SectionEnd']
    return "\n".join(lines) + "\n"


def build(args):
    project = Path(args.project).resolve(strict=True)
    app = identity(project)
    payload = project / relative(args.payload)
    output = project / relative(args.output)
    no_links(payload)
    no_links(output)
    if output.is_relative_to(payload) or payload.is_relative_to(output):
        raise DeliveryError("payload and output must not overlap")
    entry = relative(args.entry).as_posix()
    files = inventory(payload)
    if entry not in files or not entry.lower().endswith(".exe"):
        raise DeliveryError("entry EXE missing from payload")
    if any(p.split('/')[0].casefold() in ("uninstall.exe", ".git", "_helper") for p in files):
        raise DeliveryError("payload contains reserved uninstall or development files")
    target = pe_machine(payload / entry)
    engine = Path(args.engine_bundle).absolute() if args.engine_bundle else Path(__file__).resolve().parent / "engines/canghui-package"
    info, compiler = check_engine(engine)
    compile_root = engine
    if args.honor_system:
        if info.get("honorFormat") != "chui-honor-v1":
            raise DeliveryError("canghui-package engine has no paired Honor compiler/stub profile")
        compile_root = engine / "honor"
        compiler = compile_root / compiler.name
        for rel in ("honor/" + compiler.name, "honor/Stubs/zlib-x86-unicode"):
            if rel not in info["files"]:
                raise DeliveryError("incomplete Honor compiler/stub profile")
    output.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive create owns only a new output. Failed output is retained for inspection.
    output.mkdir()
    with tempfile.TemporaryDirectory(prefix="chui-package-") as temp:
        stage = Path(temp)
        for rel, sha in files.items():
            dest = stage / "payload" / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(payload / rel, dest, follow_symlinks=False)
            if dest.is_symlink() or digest(dest) != sha:
                raise DeliveryError("payload changed while staging")
        script = render(app, files, entry, args.mode, args.honor_system)
        (stage / "installer.nsi").write_text(script, encoding="utf-8")
        env = os.environ.copy()
        env["NSISDIR"] = str(compile_root)
        env.pop("NSISCONFDIR", None)
        command = [str(compiler), "-NOCONFIG", "-V2", "installer.nsi"]
        if sys.platform == "win32":
            command = [str(compiler), "/NOCONFIG", "/V2", "installer.nsi"]
        result = subprocess.run(command, cwd=stage, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=300)
        if result.returncode:
            raise DeliveryError("NSIS compile failed: " + result.stdout.decode(errors="replace")[-8000:])
        pe_machine(stage / "package.exe")
        if args.honor_system:
            data = (stage / "package.exe").read_bytes()
            if b"IUHCHnor1Format!" not in data:
                raise DeliveryError("Honor output format marker missing; compiler/stub pairing rejected")
        artifact = output / (app["identifier"] + "-" + args.mode + ".exe")
        shutil.copyfile(stage / "package.exe", artifact)
        (output / "installer.nsi").write_text(script, encoding="utf-8")
        # License for the embedded installer engine always travels beside the artifact.
        shutil.copyfile(engine / "COPYING", output / "NSIS-COPYING.txt")
        receipt = {"schema": "chui.installer-artifact.v1", "application": app,
                   "mode": args.mode, "engine": "canghui-package", "backend": "NSIS",
                   "engineVersion": info["version"], "engineHost": info["host"],
                   "engineManifestSha256": digest(engine / "engine.json"), "target": target,
                   "artifact": artifact.name, "sha256": digest(artifact), "payload": files,
                   "compiled": True, "windowsExecutionVerified": False, "signed": False,
                   "runtimeDependenciesVerified": False, "honorSystem": args.honor_system,
                   "extractionProtection": False, "selfDelete": False,
                   "headerObfuscation": "chui-honor-v1" if args.honor_system else "none",
                   "cache": "os-private-temp" if args.mode == "portable" else "not-applicable",
                   "cleanup": "on-launcher-exit-best-effort" if args.mode == "portable" else "exact-installed-files"}
        (output / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=["windows"])
    parser.add_argument("project", nargs="?", default=".")
    parser.add_argument("--payload", required=True, help="project-relative runnable Windows application directory")
    parser.add_argument("--entry", required=True, help="payload-relative executable")
    parser.add_argument("--mode", choices=["install", "portable"], default="install")
    parser.add_argument("--output", required=True, help="new project-relative output directory")
    parser.add_argument("--engine-bundle", help="explicit trusted private engine directory; never discovered on PATH")
    parser.add_argument("--honor-system", action="store_true", help="paired header-format obfuscation; not encryption or unbreakable extraction protection")
    args = parser.parse_args()
    try:
        print(json.dumps(build(args), ensure_ascii=False, indent=2))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
