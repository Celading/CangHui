#!/usr/bin/env python3
"""Input/transaction policy; native ELF relocation is tested on Linux separately."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("assembler", Path(__file__).with_name("assemble-linux-runtime.py"))
assembly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembly)


class AssemblyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.manifest = self.base / "input.json"
        self.binary = self.base / "app"
        self.binary.write_bytes(b"unit application")
        self.library = self.base / "library"
        self.library.write_bytes(b"unit library")
        self.notice = self.base / "notice.txt"
        self.notice.write_bytes(b"verbatim notice\n")
        self.output = self.base / "output"
        self.output.mkdir()
        self.system = self.base / "system"
        self.system.mkdir()
        record = lambda path: {"source": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        self.data = {"schema": assembly.SCHEMA, "machine": "AArch64",
                     "libraries": [{"name": "libsample.so.1", **record(self.library), "licenses": [record(self.notice)]}],
                     "font": {**record(self.library), "licenses": [record(self.notice)]},
                     "notices": [record(self.notice)], "systemDirectories": ["system"]}
        self.save()

    def save(self):
        self.manifest.write_text(json.dumps(self.data))

    def test_hash_pinned_records_and_license_bytes(self):
        profile = assembly.load_profile(self.manifest)
        self.assertEqual(profile["libraries"][0]["path"], self.library.resolve())
        stage = self.base / "stage"
        (stage / "runtime/licenses").mkdir(parents=True)
        paths = assembly.notice_paths(profile["notices"], stage)
        self.assertEqual((stage / paths[0]).read_bytes(), self.notice.read_bytes())

    def test_changed_source_hash_rejected(self):
        self.library.write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            assembly.load_profile(self.manifest)

    def test_missing_licenses_and_unknown_fields_rejected(self):
        original = copy.deepcopy(self.data)
        for change in ("license", "unknown", "machine-type"):
            self.data = copy.deepcopy(original)
            if change == "license":
                self.data["libraries"][0]["licenses"] = []
            elif change == "unknown":
                self.data["autoDownload"] = True
            else:
                self.data["machine"] = []
            self.save()
            with self.subTest(change=change), self.assertRaises(ValueError):
                assembly.load_profile(self.manifest)

    def test_duplicate_json_keys_rejected(self):
        self.manifest.write_text('{"schema":"first","schema":"second"}')
        with self.assertRaisesRegex(ValueError, "duplicate"):
            assembly.load_profile(self.manifest)

    def test_duplicate_traversal_and_system_libraries_rejected(self):
        for name in ["../lib.so", "libc.so.6", "lib.so;command", "-bad.so"]:
            self.data["libraries"][0]["name"] = name
            self.save()
            with self.subTest(name=name), self.assertRaises(ValueError):
                assembly.load_profile(self.manifest)
        self.data["libraries"][0]["name"] = "libgood.so"
        self.data["libraries"].append(copy.deepcopy(self.data["libraries"][0]))
        self.save()
        with self.assertRaisesRegex(ValueError, "duplicate"):
            assembly.load_profile(self.manifest)

    def test_fifo_manifest_rejected_without_open(self):
        self.manifest.unlink()
        os.mkfifo(self.manifest)
        with self.assertRaisesRegex(ValueError, "regular ELF"):
            assembly.load_profile(self.manifest)

    def test_existing_output_and_broken_symlink_not_replaced(self):
        for name in assembly.RESERVED:
            destination = self.output / name
            destination.symlink_to(self.base / "absent")
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "already exists"):
                assembly.assemble(self.output, self.binary, self.manifest, "dev.test")
            self.assertTrue(destination.is_symlink())
            destination.unlink()

    def test_failed_relocation_keeps_original_and_no_success_receipt(self):
        original = self.binary.read_bytes()
        metadata = {"machine": "AArch64", "sha256": hashlib.sha256(original).hexdigest()}
        with patch.object(assembly.elf, "inspect", return_value=metadata), \
                patch.object(assembly, "relocate", side_effect=ValueError("relocation rejected")):
            with self.assertRaisesRegex(ValueError, "relocation rejected"):
                assembly.assemble(self.output, self.binary, self.manifest, "dev.test")
        self.assertEqual(self.binary.read_bytes(), original)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_identifier_contract_and_argv_preservation(self):
        for value in ["dev.demo", "-demo", "1", "_1", "a-b"]:
            script = assembly.launcher(value)
            self.assertIn('"$@"', script)
            self.assertIn(f'/bin/{value}.bin', script)
        for value in ["../evil", "x;cmd", "a..b", ".demo", "demo.", "--", "a\ncmd"]:
            with self.assertRaises(ValueError):
                assembly.launcher(value)


if __name__ == "__main__":
    unittest.main()
