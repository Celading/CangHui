import argparse
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import installer as m


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="chui-delivery-test-")
        self.root = Path(self.temp.name).resolve()
        self.addCleanup(self.temp.cleanup)
        (self.root / "canghui.toml").write_text('[application]\nname="示例 App"\nidentifier="dev.test.app"\nversion="1.2.3"\n')
        self.payload = self.root / "payload"
        self.payload.mkdir()
        data = bytearray(256)
        data[:2] = b"MZ"
        struct.pack_into("<I", data, 60, 128)
        data[128:132] = b"PE\0\0"
        struct.pack_into("<H", data, 132, 0x8664)
        struct.pack_into("<H", data, 150, 2)
        (self.payload / "app.exe").write_bytes(data)

    def args(self, **changes):
        a = dict(project=str(self.root), payload="payload", entry="app.exe", output="dist/result",
                 engine_bundle=str(self.root / "engine"), mode="portable", honor_system=False)
        a.update(changes)
        return argparse.Namespace(**a)

    def engine(self):
        root = self.root / "engine"
        (root / "Stubs").mkdir(parents=True)
        exe = "makensis.exe" if os.name == "nt" else "makensis"
        for rel in (exe, "COPYING", "Stubs/zlib-x86-unicode"):
            (root / rel).write_text("fixture")
        info = dict(schema=m.SCHEMA, host=m.host_tag(), version="3.12", files=m.inventory(root))
        (root / "engine.json").write_text(json.dumps(info))
        return root

    def test_path_rejections(self):
        for v in ("../a", "/a", "a//b", "a/./b", "C:/foo", "a\\b", "a:stream", "CON.txt",
                  "LPT9", "x.", "x ", "x*", "$TEMP", "a\nb", "a\"b", ""):
            with self.subTest(v=v), self.assertRaises(m.DeliveryError):
                m.relative(v)
        self.assertEqual(m.relative("资源/Space File.txt").as_posix(), "资源/Space File.txt")

    def test_identity(self):
        self.assertEqual(m.identity(self.root)["name"], "示例 App")
        self.assertEqual(m.quote('$"test'), '"$$$\\"test"')
        with self.assertRaises(m.DeliveryError):
            m.quote("x\n!system evil")

    def test_payload_symlink(self):
        (self.payload / "alias").symlink_to(self.root / "canghui.toml")
        with self.assertRaises(m.DeliveryError):
            m.inventory(self.payload)

    def test_case_collision(self):
        # Case-sensitive directory where supported; on macOS also test parent names via walk fixture.
        with patch.object(m.os, "walk", return_value=[(str(self.payload), [], ["app.exe", "APP.EXE"])]):
            with self.assertRaisesRegex(m.DeliveryError, "collision"):
                m.inventory(self.payload)

    def test_budget(self):
        with patch.object(m, "MAX_BYTES", 1), self.assertRaises(m.DeliveryError):
            m.inventory(self.payload)

    def test_directory_entry_budget(self):
        (self.payload / "empty").mkdir()
        with patch.object(m, "MAX_FILES", 1), self.assertRaises(m.DeliveryError):
            m.inventory(self.payload)

    def test_manifest_malformed_table(self):
        (self.root / "canghui.toml").write_text('application = "invalid"')
        with self.assertRaisesRegex(m.DeliveryError, "TOML table"):
            m.identity(self.root)

    def test_engine_tamper_extra_and_host(self):
        root = self.engine()
        self.assertEqual(m.check_engine(root)[0]["version"], "3.12")
        (root / "COPYING").write_text("changed")
        with self.assertRaisesRegex(m.DeliveryError, "hash"):
            m.check_engine(root)

    def test_engine_wrong_host(self):
        root = self.engine()
        info = json.loads((root / "engine.json").read_text())
        info["host"] = "other"
        (root / "engine.json").write_text(json.dumps(info))
        with self.assertRaisesRegex(m.DeliveryError, "host"):
            m.check_engine(root)

    def test_engine_extra_file(self):
        root = self.engine()
        (root / "extra").write_text("unlisted")
        with self.assertRaisesRegex(m.DeliveryError, "hash"):
            m.check_engine(root)

    def test_engine_malformed_shape(self):
        root = self.engine()
        (root / "engine.json").write_text("[]")
        with self.assertRaisesRegex(m.DeliveryError, "object"):
            m.check_engine(root)

    def test_dll_rejected(self):
        file = self.payload / "app.exe"
        data = bytearray(file.read_bytes())
        struct.pack_into("<H", data, 150, 0x2002)
        file.write_bytes(data)
        with self.assertRaisesRegex(m.DeliveryError, "not a DLL"):
            m.pe_machine(file)

    def test_output_symlink(self):
        (self.root / "link").symlink_to(self.payload, target_is_directory=True)
        with self.assertRaisesRegex(m.DeliveryError, "symlink"):
            m.build(self.args(output="link/out"))

    def test_changed_staging_input(self):
        self.engine()
        real_copy = m.shutil.copyfile
        def corrupt(src, dst, **kwargs):
            result = real_copy(src, dst, **kwargs)
            Path(dst).write_bytes(b"changed")
            return result
        with patch.object(m.shutil, "copyfile", side_effect=corrupt), self.assertRaisesRegex(m.DeliveryError, "changed"):
            m.build(self.args())
        self.assertFalse((self.root / "dist/result/receipt.json").exists())

    def test_payload_paths_not_commands(self):
        names = {"资源/Space File.txt": "a", "app.exe": "b"}
        script = m.render(m.identity(self.root), names, "app.exe", "install", False)
        self.assertIn('File "payload/资源/Space File.txt"', script)
        self.assertIn('/SD IDNO', script)
        self.assertNotIn("!system", script)

    def test_bundle(self):
        import bundle
        root = self.engine()
        out = self.root / "standalone"
        receipt = bundle.bundle(self.payload / "app.exe", root, out)
        self.assertEqual(receipt["engineVersion"], "3.12")
        self.assertTrue((out / "cuic-delivery/installer.py").is_file())
        m.check_engine(out / "cuic-delivery/engines/nsis")
        with self.assertRaises(FileExistsError):
            bundle.bundle(self.payload / "app.exe", root, out)

    def test_engine_missing_no_path_fallback(self):
        with self.assertRaises(m.DeliveryError):
            m.check_engine(self.root / "missing")

    def test_pe(self):
        self.assertEqual(m.pe_machine(self.payload / "app.exe"), "x64")
        (self.payload / "app.exe").write_bytes(b"not PE")
        with self.assertRaises(m.DeliveryError):
            m.pe_machine(self.payload / "app.exe")

    def test_overlap(self):
        with self.assertRaisesRegex(m.DeliveryError, "overlap"):
            m.build(self.args(output="payload/out"))

    def test_uninstall_reserved(self):
        (self.payload / "Uninstall.exe").write_text("collision")
        with self.assertRaisesRegex(m.DeliveryError, "reserved"):
            m.build(self.args())

    def test_portable_contract(self):
        s = m.render(m.identity(self.root), m.inventory(self.payload), "app.exe", "portable", True)
        self.assertIn("InitPluginsDir", s)
        self.assertIn("ExecWait", s)
        self.assertIn("CRCCheck force", s)
        self.assertIn("not extraction protection", s)
        self.assertNotIn("Delete", s)
        self.assertNotIn("WriteReg", s)
        self.assertNotIn("ExecShell", s)

    def test_install_exact_uninstall(self):
        s = m.render(m.identity(self.root), {"app.exe": "x", "data/a.txt": "y"}, "app.exe", "install", False)
        self.assertIn('Delete "$INSTDIR\\data\\a.txt"', s)
        self.assertIn('RMDir "$INSTDIR\\data"', s)
        self.assertNotIn("RMDir /r", s)
        self.assertIn("RequestExecutionLevel user", s)
        self.assertNotIn("HKLM", s)
        self.assertIn("CreateMutexW", s)

    def test_failed_compile_never_reports_success(self):
        self.engine()
        fake = argparse.Namespace(returncode=2, stdout=b"compile failed")
        with patch.object(m.subprocess, "run", return_value=fake), self.assertRaises(m.DeliveryError):
            m.build(self.args())
        self.assertFalse((self.root / "dist/result/receipt.json").exists())

    def test_existing_output_preserved(self):
        self.engine()
        out = self.root / "dist/result"
        out.mkdir(parents=True)
        (out / "keep").write_text("owner")
        with self.assertRaises(FileExistsError):
            m.build(self.args())
        self.assertEqual((out / "keep").read_text(), "owner")


if __name__ == "__main__":
    unittest.main()
