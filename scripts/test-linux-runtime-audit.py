#!/usr/bin/env python3
"""Portable policy/parser tests; real ELF/runtime proof is a separate Linux gate."""
import copy
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("linux_audit", Path(__file__).with_name("audit-linux-runtime.py"))
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

HEADER = """ELF Header:
  Class:                             ELF64
  Data:                              2's complement, little endian
  Type:                              DYN (Position-Independent Executable file)
  Machine:                           AArch64
      [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
 0x0000000000000001 (NEEDED) Shared library: [libc.so.6]
 0x000000000000001d (RUNPATH) Library runpath: [$ORIGIN/../lib]
Version definition section '.gnu.version_d' contains 1 entry:
  Name: GLIBC_9.99
Version needs section '.gnu.version_r' contains 1 entry:
  Name: GLIBC_2.17 Flags: none Version: 2
  Name: GLIBC_ABI_DT_RELR Flags: none Version: 3
"""


class MetadataTests(unittest.TestCase):
    def test_reads_requirements_not_exports(self):
        value = audit.parse_metadata(HEADER)
        self.assertEqual(value["needed"], ["libc.so.6"])
        self.assertEqual(value["searchPaths"], ["$ORIGIN/../lib"])
        self.assertEqual(value["requiredGlibcVersions"], ["GLIBC_2.17", "GLIBC_ABI_DT_RELR"])

    def test_rejects_unsupported_formats(self):
        for old, new in [("ELF64", "ELF32"), ("little endian", "big endian"),
                         ("AArch64", "RISC-V"), ("DYN (", "REL (")]:
            with self.subTest(new=new), self.assertRaises(ValueError):
                audit.parse_metadata(HEADER.replace(old, new))

    def test_rejects_missing_headers_and_path_dependencies(self):
        for value in ["not ELF", HEADER.replace("[libc.so.6]", "[/tmp/libc.so.6]"),
                      HEADER.replace("[libc.so.6]", "[../libc.so.6]"),
                      HEADER.replace("[libc.so.6]", "[libc.so.6]suffix]"),
                      HEADER.replace("[libc.so.6]", "[libc.so.6\nbad]")]:
            with self.assertRaises(ValueError):
                audit.parse_metadata(value)

    def test_empty_search_segment_is_retained_for_rejection(self):
        value = audit.parse_metadata(HEADER.replace("[$ORIGIN/../lib]", "[:$ORIGIN/../lib:]"))
        self.assertEqual(value["searchPaths"], ["", "$ORIGIN/../lib", ""])


class ClosureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "bundle with spaces"
        self.system = self.base / "system"
        self.table = {}
        for folder in [self.root / "bin", self.root / "lib", self.system]:
            folder.mkdir(parents=True, exist_ok=True)
        self.binary = self.add(self.root / "bin/main", ["libui.so", "libc.so.6"],
                               interpreter="/lib/ld-linux-aarch64.so.1", search=["$ORIGIN/../lib"])
        self.ui = self.add(self.root / "lib/libui.so", ["libc.so.6"])
        self.add(self.system / "libc.so.6", [])
        self.add(self.system / "ld-linux-aarch64.so.1", [])

    def add(self, path, needed, interpreter=None, search=None):
        path.write_bytes(b"unit fixture, not an ELF runtime")
        self.table[path.resolve()] = {"machine": "AArch64", "type": "DYN", "interpreter": interpreter,
                                      "needed": needed, "searchPaths": search or [],
                                      "requiredGlibcVersions": ["GLIBC_2.17"], "sha256": "fixture"}
        return path.resolve()

    def run_audit(self):
        return audit.audit(self.root, "bin/main", [self.system], reader=lambda path: copy.deepcopy(self.table[path]))

    def codes(self):
        return {entry["code"] for entry in self.run_audit()["findings"]}

    def test_metadata_ready_does_not_claim_launch_or_license(self):
        result = self.run_audit()
        self.assertEqual(result["status"], "dependency-metadata-ready")
        self.assertEqual(len(result["files"]), 2)
        self.assertEqual(result["numericGlibcFloor"], "2.17")
        self.assertIn("licenses-and-redistribution", result["notVerified"])

    def test_transitive_missing_dependency(self):
        self.table[self.ui]["needed"].append("libabsent.so")
        self.assertIn("unbundled-dependency", self.codes())

    def test_absolute_cwd_escape_and_unknown_variable_search_paths(self):
        for path in ["/opt/sdk/lib", "", "$ORIGIN/../../outside", "$LIB", "$ORIGIN/$LIB"]:
            self.table[self.binary]["searchPaths"] = [path]
            with self.subTest(path=path):
                self.assertIn("nonrelocatable-search-path", self.codes())

    def test_rejects_symlink_escape_in_search_and_dependency(self):
        (self.root / "escape").symlink_to(self.system, target_is_directory=True)
        self.table[self.binary]["searchPaths"] = ["$ORIGIN/../escape"]
        self.assertIn("nonrelocatable-search-path", self.codes())
        self.ui.unlink()
        self.ui.symlink_to(self.system / "libc.so.6")
        with self.assertRaisesRegex(ValueError, "escapes bundle"):
            self.run_audit()

    def test_architecture_and_interpreter_rejected(self):
        self.table[self.ui]["machine"] = "Advanced Micro Devices X86-64"
        self.table[self.binary]["interpreter"] = "/lib/ld-musl-aarch64.so.1"
        self.assertTrue({"architecture-mismatch", "unsupported-interpreter"} <= self.codes())

    def test_system_architecture_and_absent_system_paths(self):
        self.table[(self.system / "libc.so.6").resolve()]["machine"] = "Advanced Micro Devices X86-64"
        self.assertIn("system-architecture-mismatch", self.codes())
        (self.system / "libc.so.6").unlink()
        self.assertIn("unresolved-system-baseline", self.codes())

    def test_bundled_glibc_and_unused_payload_are_not_ready(self):
        self.add(self.root / "lib/libc.so.6", [])
        (self.root / "lib/unexpected.so").write_bytes(b"unused")
        self.assertTrue({"bundled-system-baseline", "uninspected-library-entry"} <= self.codes())

    def test_cycles_are_bounded_and_all_dependencies_inspected(self):
        self.table[self.ui]["needed"].append("libcycle.so")
        self.add(self.root / "lib/libcycle.so", ["libui.so"])
        self.assertEqual(len(self.run_audit()["files"]), 3)

    def test_numeric_glibc_order_and_named_features_remain_visible(self):
        self.table[self.ui]["requiredGlibcVersions"] = ["GLIBC_2.9", "GLIBC_2.34", "GLIBC_ABI_DT_RELR"]
        result = self.run_audit()
        self.assertEqual(result["numericGlibcFloor"], "2.34")
        self.assertIn("GLIBC_ABI_DT_RELR", result["requiredGlibcVersions"])

    def test_special_file_rejected_without_opening(self):
        pipe = self.root / "lib/pipe.so"
        os.mkfifo(pipe)
        self.table[self.ui]["needed"].append("pipe.so")
        with self.assertRaisesRegex(ValueError, "regular ELF"):
            self.run_audit()

    def test_system_directory_inside_bundle_rejected(self):
        with self.assertRaisesRegex(ValueError, "outside the bundle"):
            audit.audit(self.root, "bin/main", [self.root / "lib"], reader=lambda path: self.table[path])


if __name__ == "__main__":
    unittest.main()
