#!/usr/bin/env python3
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path
import tempfile
import tomllib
import unittest

spec = importlib.util.spec_from_file_location("kit_export", Path(__file__).with_name("export-kit-source.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class KitExportTest(unittest.TestCase):
    def test_each_package_copies_only_selected_closure(self):
        with tempfile.TemporaryDirectory() as folder:
            for name, identity in module.KITS.items():
                output = Path(folder) / name
                receipt = module.export(name, module.ROOT, output)
                self.assertEqual(receipt["package"], identity)
                self.assertEqual(receipt["resources"], [])
                self.assertEqual(receipt["nativeDependencies"], [])
                self.assertEqual(set(tomllib.loads((output / "cjpm.toml").read_text())["dependencies"]), {"chui"})
                self.assertEqual(set(p.name for p in output.iterdir()),
                                 {"src", "README.md", "cjpm.toml", "kit-source.json", "OWNED-SOURCE.md", *module.NOTICES})
                for path, digest in receipt["files"].items():
                    self.assertEqual(hashlib.sha256((output / path).read_bytes()).hexdigest(), digest)
                self.assertEqual(json.loads((output / "kit-source.json").read_text()), receipt)

    def test_repeat_export_never_overwrites_owned_edits(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "owned"
            module.export("kit", module.ROOT, output)
            marker = output / "src/design.cj"
            marker.write_text("application-owned changes")
            with self.assertRaisesRegex(ValueError, "output exists"):
                module.export("kit", module.ROOT, output)
            self.assertEqual(marker.read_text(), "application-owned changes")

    def test_existing_symlink_and_framework_descendant_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "alias"
            output.symlink_to(Path(folder) / "missing")
            with self.assertRaisesRegex(ValueError, "output exists"):
                module.export("kit", module.ROOT, output)
            with self.assertRaisesRegex(ValueError, "outside"):
                module.export("kit", module.ROOT, module.ROOT / "export-forbidden")

    def test_wrong_framework_identity_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "cjpm.toml").write_text('[package]\nname="not_chui"\nversion="1.0.0"\n')
            with self.assertRaisesRegex(ValueError, "identity"):
                module.export("kit", root, root.parent / "should-not-be-created")

    def test_new_upgrade_candidate_leaves_owned_copy_untouched(self):
        with tempfile.TemporaryDirectory() as folder:
            first, second = Path(folder) / "owned", Path(folder) / "candidate"
            module.export("kit", module.ROOT, first)
            (first / "src/design.cj").write_text("application-owned changes")
            receipt = module.export("kit", module.ROOT, second)
            self.assertEqual((first / "src/design.cj").read_text(), "application-owned changes")
            self.assertEqual(hashlib.sha256((second / "src/design.cj").read_bytes()).hexdigest(),
                             receipt["sourceFiles"]["src/design.cj"])

    def test_unreviewed_resources_and_symlink_sources_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "source"
            package = source / "packages/kit"
            shutil.copytree(module.ROOT / "packages/kit", package, ignore=shutil.ignore_patterns("target"))
            for name in module.NOTICES:
                shutil.copyfile(module.ROOT / name, source / name)
            resource = package / "assets"
            resource.mkdir()
            with self.assertRaisesRegex(ValueError, "resources changed"):
                module.export("kit", module.ROOT, Path(folder) / "refused-resource", source)
            resource.rmdir()
            (package / "src/alias.cj").symlink_to(package / "src/design.cj")
            with self.assertRaisesRegex(ValueError, "unexpected source"):
                module.export("kit", module.ROOT, Path(folder) / "refused-link", source)


if __name__ == "__main__":
    unittest.main()
