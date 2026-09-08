#!/usr/bin/env python3
"""Portable exporter policy tests; fixture bytes are not native execution proof."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("linux_sdk", Path(__file__).with_name("build-linux-source-sdk.py"))
sdk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sdk)


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def profile(self):
        def record(name):
            path = self.root / name
            path.write_bytes((name + " source bytes").encode())
            return {"path": path, "sha256": sdk.elf.digest(path)}
        notice = record("license.txt")
        font = record("font.ttf")
        return {"machine": "AArch64", "libraries": [
            {"name": name, **record(name), "licenses": [notice]} for name in sdk.ALIASES.values()],
            "font": {**font, "licenses": [notice]}, "notices": [notice],
            "systemDirectories": [Path("/usr/lib/aarch64-linux-gnu")]}

    def test_profile_requires_matching_machine_loader_names_and_standard_baseline(self):
        profile = self.profile()
        sdk.validate_profile(profile, "aarch64")
        for mutation in (lambda p: p.update(machine="Advanced Micro Devices X86-64"),
                         lambda p: p["libraries"].pop(),
                         lambda p: p["libraries"].append({"name": "libSDL3.so"}),
                         lambda p: p.update(systemDirectories=[Path("/tmp/private-sysroot")])):
            invalid = copy.deepcopy(profile)
            mutation(invalid)
            with self.assertRaises(ValueError):
                sdk.validate_profile(invalid, "aarch64")

    def test_profile_bounds_include_generated_aliases(self):
        profile = self.profile()
        profile["libraries"] += [{"name": f"libfixture{i}.so"} for i in range(124)]
        with self.assertRaisesRegex(ValueError, "count"):
            sdk.validate_profile(profile, "aarch64")

    def test_native_projection_preserves_sources_and_relocatable_notices(self):
        profile = self.profile()
        output = self.root / "candidate"
        output.mkdir()
        def relocate(path, value):
            self.assertEqual(value, "$ORIGIN")
            path.write_bytes(path.read_bytes() + b" relocated fixture")
        with patch.object(sdk.elf, "inspect", return_value={"machine": "AArch64"}), \
                patch.object(sdk.assembly, "relocate", side_effect=relocate):
            inventory = sdk.copy_native(output, profile)
        for source, item in zip(profile["libraries"], inventory):
            self.assertEqual(sdk.elf.digest(source["path"]), source["sha256"])
            self.assertNotEqual(item["inputSha256"], item["sha256"])
        for alias, loader in sdk.ALIASES.items():
            self.assertFalse((output / "native" / alias).is_symlink())
            self.assertEqual((output / "native" / alias).read_bytes(), (output / "native" / loader).read_bytes())
        portable = json.loads((output / "runtime/native-input.json").read_text())
        self.assertNotIn(str(self.root), json.dumps(portable))
        self.assertEqual(len(portable["libraries"]), 2)  # aliases are not app runtime inputs
        records = [portable["font"], *portable["libraries"], *portable["notices"],
                   *portable["font"]["licenses"], *portable["libraries"][0]["licenses"]]
        for record in records:
            path = output / "runtime" / record["source"]
            self.assertEqual(sdk.elf.digest(path), record["sha256"])

    def test_wrong_architecture_is_rejected_before_relocation(self):
        profile = self.profile()
        output = self.root / "candidate"
        output.mkdir()
        with patch.object(sdk.elf, "inspect", return_value={"machine": "wrong"}), \
                patch.object(sdk.assembly, "relocate") as relocate, self.assertRaises(ValueError):
            sdk.copy_native(output, profile)
        relocate.assert_not_called()

    def test_sdl_projection_requires_exact_two_declarations(self):
        (self.root / "sdl").mkdir()
        manifest = self.root / "sdl/cjpm.toml"
        for count in (0, 1, 3):
            source = 'path = "./.sdl3"\n' * count
            manifest.write_text(source)
            with self.assertRaises(ValueError):
                sdk.manifest_projection(self.root)
            self.assertEqual(manifest.read_text(), source)
        manifest.write_text('path = "./.sdl3"\n' * 2)
        sdk.manifest_projection(self.root)
        self.assertEqual(manifest.read_text(), 'path = "../../native"\n' * 2)

    def test_ledger_covers_regular_bytes_and_refuses_overwrite(self):
        output = self.root / "candidate"
        output.mkdir()
        (output / "sample.txt").write_text("unchanged")
        archive = sdk.seal(output)
        self.assertTrue(archive.is_file())
        self.assertEqual((output / "SHA256SUMS").read_text(),
                         sdk.sdk.sha(output / "sample.txt") + "  sample.txt\n")
        prior = archive.read_bytes()
        with self.assertRaises(FileExistsError):
            sdk.seal(output)
        self.assertEqual(archive.read_bytes(), prior)

    def test_ledger_rejects_links_before_creation(self):
        output = self.root / "candidate"
        output.mkdir()
        (output / "link").symlink_to("missing")
        with self.assertRaises(ValueError):
            sdk.seal(output)
        self.assertFalse((output / "SHA256SUMS").exists())

    def test_shared_cli_builder_embeds_same_commit_for_both_flavors(self):
        revision = "a" * 40
        seen = []
        def export(actual_revision, paths, staging):
            self.assertEqual(actual_revision, revision)
            self.assertEqual(paths, ["tools/cuic"])
            cli = staging / "tools/cuic"
            (cli / "src").mkdir(parents=True)
            (cli / "cjpm.toml").write_text('version = "0.6.0"\ncompile-option = "--static"\n')
        def build(command, cwd, check):
            self.assertTrue(check)
            identity = (cwd / "src/build_identity.cj").read_text()
            self.assertIn(revision, identity)
            self.assertIn('"source-sdk"', identity)
            self.assertIn("--trimpath", (cwd / "cjpm.toml").read_text())
            flavor = "debug" if "-g" in command else "release"
            binary = cwd / "target" / flavor / "bin/main"
            binary.parent.mkdir(parents=True)
            binary.write_text(flavor)
        with patch.object(sdk.sdk, "export_revision", side_effect=export), \
                patch.object(sdk.sdk.subprocess, "run", side_effect=build), \
                patch.object(sdk.sdk, "run", return_value="fixture CLI, not executed"):
            version = sdk.sdk.build_cli_pair(self.root, revision, lambda path: seen.append((path.name, path.read_text())))
        self.assertEqual(version, "0.6.0")
        self.assertEqual(seen, [("cuic", "release"), ("cuic-debug", "debug")])


if __name__ == "__main__":
    unittest.main()
