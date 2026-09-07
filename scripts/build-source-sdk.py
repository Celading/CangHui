#!/usr/bin/env python3
"""Build one immutable macOS/arm64 source SDK from a committed revision.

No downloads, checkout mutation, publisher signing, or package-manager installation.
The compiler remains a separately installed build prerequisite. Native payloads are
copied from this host, relocated, ad-hoc signed, inventoried and checksummed.
"""
import argparse
import hashlib
import io
import json
import pathlib
import platform
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE_ROOTS = ["src", "sdl/src", "sdl/cjpm.toml", "cjpm.toml", "LICENSE", "NOTICE",
                "assets/fonts", "packages/kit", "manual"]


def run(*args, cwd=None):
    return subprocess.check_output(list(map(str, args)), cwd=cwd, text=True).strip()


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def export_revision(revision, paths, output):
    raw = subprocess.check_output(["git", "-C", str(ROOT), "archive", revision, *paths])
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        for item in archive.getmembers():
            path = pathlib.PurePosixPath(item.name)
            if path.is_absolute() or ".." in path.parts or not (item.isfile() or item.isdir()):
                raise ValueError(f"unsafe SDK source entry: {item.name}")
            if any(part in {"_helper", ".git", "target", ".agents", ".codex"} for part in path.parts):
                raise ValueError(f"internal/build entry in SDK source: {item.name}")
        archive.extractall(output, filter="data")


def version(manifest):
    return re.search(r'^version\s*=\s*"([^"]+)"', manifest.read_text(), re.M)[1]


def dependencies(binary):
    return [line.strip().split(" (compatibility", 1)[0]
            for line in run("otool", "-L", binary).splitlines()[1:]]


def minimum_os(binary):
    text = run("otool", "-l", binary)
    values = re.findall(r"\bminos\s+([0-9.]+)", text)
    values += re.findall(r"LC_VERSION_MIN_MACOSX\s+cmdsize\s+\d+\s+version\s+([0-9.]+)", text)
    if not values:
        raise ValueError(f"missing Mach-O deployment floor: {binary.name}")
    return max(tuple(map(int, v.split("."))) + (0,) * (3 - len(v.split("."))) for v in values)


def system_dependency(value):
    return value.startswith(("/usr/lib/", "/System/Library/"))


def copy_licenses(prefix, destination):
    candidates = []
    for path in prefix.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(prefix)
        if "licenses" in relative.parts or path.name.lower().startswith(("license", "copying", "copyright", "notice", "open_source_software_notice", "lgpl", "gpl", "ftl")):
            candidates.append(path)
    if not candidates:
        raise ValueError(f"no redistributable license record found for {prefix}")
    for path in candidates:
        target = destination / path.relative_to(prefix)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)


def native_closure(output):
    native = output / "native"
    native.mkdir()
    selected = {}
    origins = {}
    minimum = (0, 0, 0)

    def visit(source, name=None):
        nonlocal minimum
        source = source.resolve(strict=True)
        if source in selected:
            return selected[source]
        name = name or source.name
        if name in selected.values() or not re.fullmatch(r"[A-Za-z0-9_.-]+\.dylib", name):
            raise ValueError(f"native filename collision or invalid name: {name}")
        if len(selected) >= 64:
            raise ValueError("native closure exceeds 64-library bound")
        selected[source] = name
        if run("lipo", "-archs", source) != "arm64":
            raise ValueError(f"source SDK v1 requires an arm64 library: {source}")
        minimum = max(minimum, minimum_os(source))
        target = native / name
        shutil.copyfile(source, target)
        target.chmod(0o755)
        mappings = {}
        for dep in dependencies(source):
            if system_dependency(dep):
                continue
            if dep.startswith("@loader_path/"):
                resolved = source.parent / dep.removeprefix("@loader_path/")
            elif dep.startswith("/opt/homebrew/"):
                resolved = pathlib.Path(dep)
            else:
                raise ValueError(f"unresolved native dependency: {dep}")
            if resolved.resolve() == source:
                continue  # LC_ID_DYLIB, not an imported library
            mappings[dep] = visit(resolved)
        run("install_name_tool", "-id", "@rpath/" + name, target)
        for original, copied in mappings.items():
            run("install_name_tool", "-change", original, "@loader_path/" + copied, target)
        run("codesign", "--force", "--sign", "-", target)
        parts = source.parts
        if "Cellar" not in parts:
            raise ValueError(f"native license owner is not a Homebrew Cellar package: {source}")
        index = parts.index("Cellar")
        formula, release = parts[index + 1:index + 3]
        prefix = pathlib.Path(*parts[:index + 3])
        if formula not in origins:
            copy_licenses(prefix, output / "licenses" / formula)
            origins[formula] = {"version": release, "source": "Homebrew " + formula,
                                "licensePath": "licenses/" + formula}
            recipe = prefix / ".brew" / (formula + ".rb")
            if recipe.exists():
                text = recipe.read_text()
                for field, key in [("url", "upstreamArchive"), ("sha256", "upstreamSha256"), ("homepage", "homepage")]:
                    match = re.search(r'^\s*' + field + r'\s+"([^"\n]+)"', text, re.M)
                    if match:
                        origins[formula][key] = match[1]
        return name

    for formula, name in [("sdl3", "libSDL3.dylib"), ("sdl3_ttf", "libSDL3_ttf.dylib")]:
        visit(pathlib.Path(run("brew", "--prefix", formula)) / "lib" / name, name)
    for binary in native.iterdir():
        for dep in dependencies(binary):
            if system_dependency(dep) or dep == "@rpath/" + binary.name:
                continue
            if not dep.startswith("@loader_path/") or not (native / dep.removeprefix("@loader_path/")).is_file():
                raise ValueError(f"unclosed relocated dependency: {dep}")
        run("codesign", "--verify", "--strict", binary)
    return sorted(selected.values()), origins, minimum


def export_unicode_license(output, framework, revision):
    # Older committed SDK revisions predate Unicode tables; only project the
    # associated license when that revision actually owns it.
    unicode_license = subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e",
                                     revision + ":LICENSE-UNICODE"], capture_output=True)
    if unicode_license.returncode == 0:
        export_revision(revision, ["LICENSE-UNICODE"], framework)
        license_dir = output / "licenses/unicode"
        license_dir.mkdir(parents=True)
        shutil.copyfile(framework / "LICENSE-UNICODE", license_dir / "LICENSE-UNICODE")
    elif (framework / "src/core/unicode_grapheme_data.cj").exists():
        raise ValueError("Unicode grapheme data requires LICENSE-UNICODE in the selected revision")


def build(output, revision):
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("this exporter only validates macOS arm64")
    compiler = run("cjc", "--version")
    if compiler.splitlines() != ["Cangjie Compiler: 1.1.3 (cjnative)", "Target: aarch64-apple-darwin"]:
        raise ValueError("Cangjie 1.1.3 is required for this source SDK ABI")
    revision = run("git", "-C", ROOT, "rev-parse", revision + "^{commit}")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)  # Never overwrite an earlier delivery.
    framework = output / "framework"
    export_revision(revision, SOURCE_ROOTS, framework)
    export_unicode_license(output, framework, revision)
    if not (framework / "src/core/probe_observation.cj").exists():
        raise ValueError("selected revision predates observation/v1")
    cli_version = ""
    with tempfile.TemporaryDirectory(prefix="chui-sdk-build-") as temporary:
        staging = pathlib.Path(temporary)
        export_revision(revision, ["tools/cuic"], staging)
        cli = staging / "tools/cuic"
        cli_version = version(cli / "cjpm.toml")
        manifest = cli / "cjpm.toml"
        manifest.write_text(manifest.read_text().replace('compile-option = "',
                            'compile-option = "--trimpath ' + str(staging) + ' ', 1))
        (cli / "src/build_identity.cj").write_text(
            'package cuic\nlet CUIC_BUILD_CHANNEL = "source-sdk"\n'
            f'let CUIC_BUILD_REVISION = "{revision}"\n'
            'func renderCuicVersion(): String { "cuic ${VERSION} (${CUIC_BUILD_CHANNEL}@${CUIC_BUILD_REVISION})" }\n')
        (output / "bin").mkdir()
        for debug in [False, True]:
            command = ["cjpm", "build"]
            if debug:
                command.append("-g")
            subprocess.run(command, cwd=cli, check=True)
            name = "cuic-debug" if debug else "cuic"
            shutil.copy2(cli / "target" / ("debug" if debug else "release") / "bin/main", output / "bin" / name)
            if any(not system_dependency(d) for d in dependencies(output / "bin" / name)):
                raise ValueError("CUIC is not standalone from the build toolchain")
            print(run(output / "bin" / name, "version"), flush=True)
    compiler_root = pathlib.Path(shutil.which("cjc")).resolve().parent.parent
    copy_licenses(compiler_root, output / "licenses/cangjie")
    names, origins, minimum = native_closure(output)
    # Project the FFI manifest during SDK construction, never in a consumer cache.
    # CJPM validates ffi.c paths before invoking the linker; LIBRARY_PATH is not
    # a replacement for a missing declared directory in an isolated installation.
    sdl_manifest = framework / "sdl/cjpm.toml"
    sdl_manifest.write_text(sdl_manifest.read_text().replace('path = "./.sdl3"', 'path = "../../native"'))
    for binary in (output / "bin").iterdir():
        minimum = max(minimum, minimum_os(binary))
    manifest = {
        "schema": "canghui.source-sdk/v1", "sourceCommit": revision, "cuicVersion": cli_version,
        "frameworkVersion": version(framework / "cjpm.toml"),
        "kitVersion": version(framework / "packages/kit/cjpm.toml"), "compilerVersion": "1.1.3",
        "target": "macos-arm64", "minimumOS": ".".join(map(str, minimum)), "nativeFiles": ",".join(names)}
    (framework / "canghui-sdk.env").write_text("".join(f"{k}={v}\n" for k, v in manifest.items()))
    (output / "native-inventory.json").write_text(json.dumps({"schema": "canghui.native-inventory/v1",
        "dependencies": origins, "publisherSigning": False,
        "manifestProjection": "framework/sdl/cjpm.toml ffi.c paths -> ../../native",
        "limitations": ["same-host candidate, not notarized", "compiler installed separately",
                        "distribution/source-offer compliance requires publisher review"]}, indent=2) + "\n")
    (output / "README.md").write_text(
        f'# CangHui source SDK candidate\n\nCommit `{revision}`; macOS arm64 >= {manifest["minimumOS"]}.\n\n'
        'Requires separately installed Cangjie 1.1.3. No framework source edits or downloads are needed.\n'
        'Verify SHA256SUMS against a trusted delivery receipt before executing tools. Hashes are not publisher signatures.\n\n'
        'From outside this immutable directory, run:\n\n'
        '```sh\n/path/to/sdk/bin/cuic init Hello --canghui-path /path/to/sdk/framework\n'
        '/path/to/sdk/bin/cuic build macos Hello\n'
        '/path/to/sdk/bin/cuic-debug prnt macos Hello --output preview.png\n```\n\n'
        'Optional Kit dependency: `canghui_kit = { path = "/path/to/sdk/framework/packages/kit" }`.\n'
        'Use the same framework root for chui and Kit. Keep SDK files immutable.\n'
        'The release CLI refuses simulation; use cuic-debug with a debug app and registered probe for prntx.\n'
        'The SDK is source-based, not a precompiled Cangjie SDK or a universal cross-platform runtime.\n'
        'Use cuic-debug prntx Hello welcome.main for the generated SDK template.\n'
        'SDK .app packaging carries the verified native closure; publisher signing/notarization and field acceptance remain separate.\n')
    files = sorted(path for path in output.rglob("*") if path.is_file())
    (output / "SHA256SUMS").write_text("".join(f"{sha(p)}  {p.relative_to(output).as_posix()}\n" for p in files))
    archive_path = output.with_name(output.name + ".tar.gz")
    with archive_path.open("xb") as destination:
        with tarfile.open(fileobj=destination, mode="w:gz") as archive:
            archive.add(output, arcname=output.name)
    print(json.dumps({"sdk": str(output), "archive": str(archive_path), "sha256": sha(archive_path),
                      "sourceCommit": revision, "minimumOS": manifest["minimumOS"]}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--revision", default="HEAD")
    options = parser.parse_args()
    build(options.output, options.revision)
