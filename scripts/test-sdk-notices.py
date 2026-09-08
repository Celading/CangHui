#!/usr/bin/env python3
"""Check source-SDK notice selection/projection without building native libraries."""
import pathlib
import runpy
import tempfile
import unittest

SDK = runpy.run_path(str(pathlib.Path(__file__).with_name("build-source-sdk.py")))
REQUIRED = ("LICENSE", "NOTICE", "THIRD_PARTY_NOTICES.md")


class SourceNoticeTests(unittest.TestCase):
    def test_source_selection_retains_all_referenced_framework_notices(self):
        for name in REQUIRED:
            with self.subTest(name=name):
                self.assertIn(name, SDK["SOURCE_ROOTS"])

    def test_projection_is_byte_exact_and_carries_optional_unicode(self):
        with tempfile.TemporaryDirectory(prefix="chui-sdk-notices-") as temporary:
            output = pathlib.Path(temporary)
            framework = output / "framework"
            framework.mkdir()
            for name in (*REQUIRED, "LICENSE-UNICODE"):
                (framework / name).write_bytes(f"unchanged {name}\r\n".encode())
            SDK["copy_framework_notices"](output, framework)
            for name in (*REQUIRED, "LICENSE-UNICODE"):
                self.assertEqual((output / "licenses/canghui" / name).read_bytes(),
                                 (framework / name).read_bytes())

    def test_missing_required_notice_rejects_candidate(self):
        with tempfile.TemporaryDirectory(prefix="chui-sdk-notices-") as temporary:
            output = pathlib.Path(temporary)
            framework = output / "framework"
            framework.mkdir()
            for name in REQUIRED[:-1]:
                (framework / name).write_text("fixture")
            with self.assertRaisesRegex(ValueError, "THIRD_PARTY_NOTICES"):
                SDK["copy_framework_notices"](output, framework)

    def test_historical_source_without_unicode_needs_no_synthetic_notice(self):
        with tempfile.TemporaryDirectory(prefix="chui-sdk-notices-") as temporary:
            output = pathlib.Path(temporary)
            framework = output / "framework"
            framework.mkdir()
            for name in REQUIRED:
                (framework / name).write_text("fixture")
            SDK["copy_framework_notices"](output, framework)
            self.assertFalse((output / "licenses/canghui/LICENSE-UNICODE").exists())

    def test_linked_notice_is_rejected_before_projection(self):
        for name in (*REQUIRED, "LICENSE-UNICODE"):
            with self.subTest(name=name), tempfile.TemporaryDirectory(prefix="chui-sdk-notices-") as temporary:
                output = pathlib.Path(temporary)
                framework = output / "framework"
                framework.mkdir()
                for required in REQUIRED:
                    if required != name:
                        (framework / required).write_text("fixture")
                (framework / name).symlink_to("missing-notice")
                with self.assertRaisesRegex(ValueError, "non-regular framework notice"):
                    SDK["copy_framework_notices"](output, framework)
                self.assertFalse((output / "licenses/canghui").exists())


if __name__ == "__main__":
    unittest.main()
