#!/usr/bin/env python3
"""Native-free tests of source SDK Unicode license projection; no SDK delivery claim."""
import pathlib
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SDK = runpy.run_path(str(pathlib.Path(__file__).with_name("build-source-sdk.py")))
EXPORT = SDK["export_unicode_license"]


class UnicodeLicenseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="chui-unicode-license-")
        self.addCleanup(self.directory.cleanup)
        self.output = pathlib.Path(self.directory.name)
        self.framework = self.output / "framework"
        self.framework.mkdir()

    def project(self, license_present):
        def archive(revision, paths, destination):
            self.assertEqual(revision, "exact-revision")
            self.assertEqual(paths, ["LICENSE-UNICODE"])
            (destination / "LICENSE-UNICODE").write_bytes(b"fixture license\n")

        with patch.dict(EXPORT.__globals__, {"export_revision": archive}):
            with patch("subprocess.run", return_value=subprocess.CompletedProcess([], 0 if license_present else 1)) as check:
                EXPORT(self.output, self.framework, "exact-revision")
                self.assertEqual(check.call_args.args[0][-1], "exact-revision:LICENSE-UNICODE")

    def test_license_copied_to_source_and_distribution(self):
        self.project(True)
        self.assertEqual((self.framework / "LICENSE-UNICODE").read_bytes(), b"fixture license\n")
        self.assertEqual((self.output / "licenses/unicode/LICENSE-UNICODE").read_bytes(), b"fixture license\n")

    def test_old_revision_without_unicode_stays_compatible(self):
        self.project(False)
        self.assertFalse((self.output / "licenses/unicode").exists())

    def test_data_without_license_fails_closed(self):
        data = self.framework / "src/core/unicode_grapheme_data.cj"
        data.parent.mkdir(parents=True)
        data.write_text("fixture Unicode data")
        with self.assertRaisesRegex(ValueError, "requires LICENSE-UNICODE"):
            self.project(False)


if __name__ == "__main__":
    unittest.main()
