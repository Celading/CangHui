#!/usr/bin/env python3
"""Bounded Harmony projection file-type regressions; no device or provider execution."""
import argparse
import os
import pathlib
import signal
import subprocess
import tempfile
import unittest


class HarmonyFileTypeTests(unittest.TestCase):
    cuic = None
    framework = None

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="chui-harmony-type-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.project = self.root / "app"
        self.provider = self.root / "provider"
        for path in (self.project / "src", self.project / "assets", self.provider):
            path.mkdir(parents=True)
        (self.project / "cjpm.toml").write_text(
            '[package]\nname = "consumer"\nversion = "1.0.0"\n'
            '[dependencies]\nchui = { path = "' + str(self.framework) + '" }\n')
        (self.project / "canghui.toml").write_text(
            '[application]\nname = "Consumer"\nidentifier = "dev.example.consumer"\nversion = "1.0.0"\n'
            '[assets]\nresources = ["assets"]\n'
            '[harmony]\nsource-roots = ["src"]\ntarget-package = "dev.example.consumer"\n'
            'output = "generated/harmony"\n')
        (self.project / "src/main.cj").write_text("package consumer\n")
        (self.project / "assets/data.bin").write_bytes(b"resource")
        (self.provider / "payload.so").write_bytes(b"synthetic, never executed")
        (self.provider / "canghui-harmony-provider.env").write_text(
            'schema=canghui.harmony-provider/v1\nproviderVersion=test\nframeworkVersion=0.17.0\n'
            'frameworkCommit=' + '1' * 40 + '\nframeworkAbi=canghui.harmony-native-surface/v1\n'
            'inputAbi=canghui.harmony-pointer/v2\nprojectionProtocol=canghui.harmony-projection/v1\n'
            'targetAbi=arm64-v8a\nartifacts=payload.so\n')

    def prepare(self):
        command = [self.cuic, "prepare", "harmony", str(self.project),
                   "--provider", str(self.provider), "--json"]
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, start_new_session=True) as process:
            try:
                stdout, stderr = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
                self.fail("Harmony projection waited for a special-file writer")
            return process.returncode, stdout + stderr

    def fifo_rejected(self, path):
        path.unlink()
        os.mkfifo(path, 0o600)
        code, output = self.prepare()
        self.assertEqual(code, 1, output)
        self.assertIn("regular file", output)

    def test_regular_projection_and_unchanged_replay(self):
        code, first = self.prepare()
        self.assertEqual(code, 0, first)
        code, second = self.prepare()
        self.assertEqual(code, 0, second)
        self.assertEqual(first, second)

    def test_provider_manifest_fifo(self):
        self.fifo_rejected(self.provider / "canghui-harmony-provider.env")

    def test_provider_payload_fifo(self):
        self.fifo_rejected(self.provider / "payload.so")

    def test_source_fifo(self):
        self.fifo_rejected(self.project / "src/main.cj")

    def test_resource_fifo(self):
        self.fifo_rejected(self.project / "assets/data.bin")

    def test_cached_receipt_fifo(self):
        code, output = self.prepare()
        self.assertEqual(code, 0, output)
        self.fifo_rejected(self.project / "generated/harmony/canghui-harmony-projection-receipt.json")

    def test_cached_output_fifo(self):
        code, output = self.prepare()
        self.assertEqual(code, 0, output)
        self.fifo_rejected(self.project / "generated/harmony/cangjie/src/main.cj")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cuic", required=True, type=pathlib.Path)
    options, remaining = parser.parse_known_args()
    HarmonyFileTypeTests.cuic = str(options.cuic.resolve(strict=True))
    HarmonyFileTypeTests.framework = pathlib.Path(__file__).resolve().parents[1]
    unittest.main(argv=[__file__, *remaining])
