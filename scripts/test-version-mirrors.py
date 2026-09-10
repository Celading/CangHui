#!/usr/bin/env python3
"""Keep runtime and provider version mirrors inside the public audit gate."""
import importlib.util
import pathlib
import shutil
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location(
    "public_audit", ROOT / "manual/skills/canghui-full-build/scripts/audit_public_surface.py")
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class VersionMirrors(unittest.TestCase):
    def test_each_runtime_mirror_is_checked_independently(self):
        paths = ["cjpm.toml", "README.md", "README.zh-CN.md", "manual/index.md",
                 "manual/CHANGELOG.md", "src/symbol/symbol.cj", "src/chui.cj",
                 "tools/cuic/cjpm.toml", "tools/cuic/src/main.cj",
                 "tools/cuic/src/harmony_provider_pack.cj",
                 "platform/harmony/provider/canghui-harmony-provider-contract.env"]
        with tempfile.TemporaryDirectory(prefix="chui-version-mirrors-") as scratch:
            root = pathlib.Path(scratch)
            for relative in paths:
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            (root / "manual/api/chui").mkdir(parents=True)
            errors = []
            AUDIT.audit_version_and_identity(root, errors)
            self.assertEqual(errors, [])
            for relative in paths[-3:]:
                with self.subTest(mirror=relative):
                    target = root / relative
                    original = target.read_text()
                    target.write_text("stale-version-mirror\n")
                    errors = []
                    AUDIT.audit_version_and_identity(root, errors)
                    self.assertEqual(len(errors), 1)
                    self.assertIn(target.name, errors[0])
                    target.write_text(original)


if __name__ == "__main__":
    unittest.main()
