#!/usr/bin/env python3
"""Bounded SDK verifier integration tests; never execute the candidate's binaries.

Usage: python3 scripts/test-sdk-file-types.py --cuic /absolute/path/to/cuic
Synthetic payloads prove file-type/integrity validation, not native runtime delivery.
"""
import argparse
import hashlib
import json
import os
import pathlib
import signal
import socket
import subprocess
import tempfile
import unittest


class SdkFileTypeTests(unittest.TestCase):
    cuic = None

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="chui-sdk-type-")
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        files = {
            "framework/canghui-sdk.env": (
                "schema=canghui.source-sdk/v1\nsourceCommit=" + "1" * 40 +
                "\ncuicVersion=0.6.0\nframeworkVersion=0.17.0\nkitVersion=0.1.0\n"
                "compilerVersion=1.1.3\ntarget=macos-arm64\nminimumOS=15.0\n"
                "nativeFiles=libSDL3.dylib,libSDL3_ttf.dylib\n"),
            "framework/cjpm.toml": '[package]\nname = "chui"\nversion = "0.17.0"\n',
            "framework/packages/kit/cjpm.toml": '[package]\nname = "canghui_kit"\nversion = "0.1.0"\n',
            "framework/src/chui.cj": "synthetic source",
            "bin/cuic": "not executed",
            "bin/cuic-debug": "not executed",
            "native/libSDL3.dylib": "not a native binary",
            "native/libSDL3_ttf.dylib": "not a native binary",
            "extra": "extra checksummed payload",
        }
        ledger = []
        for relative, content in files.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            data = content.encode()
            path.write_bytes(data)
            ledger.append(f"{hashlib.sha256(data).hexdigest()}  {relative}\n")
        (self.root / "SHA256SUMS").write_text("".join(ledger))

    def verify(self):
        # CUIC's hashing child shares this new process group. Kill only this test's
        # group on timeout, then reap it; no stray blocked hasher is left behind.
        command = [self.cuic, "sdk", "verify", str(self.root / "framework"), "--json"]
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, start_new_session=True) as process:
            try:
                stdout, stderr = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
                self.fail("SDK verifier timed out on a non-regular payload")
            try:
                report = json.loads(stdout)
            except json.JSONDecodeError:
                self.fail(f"verifier returned no JSON: code={process.returncode}, stderr={stderr}")
            return process.returncode, report

    def reject_non_regular(self, path):
        code, report = self.verify()
        self.assertEqual(code, 1)
        self.assertFalse(report["ok"])
        self.assertIn("regular file", report["error"])
        self.assertIn(path.name, report["error"])

    def test_regular_payload_integrity_is_not_publisher_authentication(self):
        code, report = self.verify()
        self.assertEqual(code, 0)
        self.assertTrue(report["current"]["integrityVerified"])
        self.assertFalse(report["current"]["publisherAuthenticated"])

    def test_required_source_fifo_is_rejected_without_waiting_for_a_writer(self):
        path = self.root / "framework/src/chui.cj"
        path.unlink()
        os.mkfifo(path, 0o600)
        self.reject_non_regular(path)

    def test_extra_ledger_fifo_is_also_rejected_before_hashing(self):
        path = self.root / "extra"
        path.unlink()
        os.mkfifo(path, 0o600)
        self.reject_non_regular(path)

    def test_directory_is_rejected_before_hashing(self):
        path = self.root / "extra"
        path.unlink()
        path.mkdir()
        self.reject_non_regular(path)

    def test_unix_socket_is_rejected_before_hashing(self):
        path = self.root / "extra"
        path.unlink()
        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(str(path))
            self.reject_non_regular(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cuic", required=True, type=pathlib.Path)
    options, remaining = parser.parse_known_args()
    SdkFileTypeTests.cuic = str(options.cuic.resolve(strict=True))
    unittest.main(argv=[__file__, *remaining])
