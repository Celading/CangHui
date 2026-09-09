#!/usr/bin/env python3
"""Portable failure-policy tests; not a native macOS/publisher acceptance."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("audit-macos-release.sh")
SHIM = r'''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
name = Path(sys.argv[0]).name
mode = os.environ.get("AUDIT_TEST_FAILURE", "")
args = sys.argv[1:]
key = name + (":" + args[0] if name == "otool" else "")
if key == mode:
    print("injected inspection failure: " + key, file=sys.stderr)
    sys.exit(41)
if name == "file":
    if mode != "empty-classification": print("Mach-O 64-bit executable arm64")
elif name == "codesign":
    if mode == "unsigned":
        print("code object is not signed at all", file=sys.stderr)
        sys.exit(1)
    if (mode == "metadata-failure" and "--verbose=4" in args) or (mode == "entitlements-failure" and "--entitlements" in args):
        print("injected signing inspection failure", file=sys.stderr)
        sys.exit(41)
    print("<plist><dict/></plist>")
elif name == "strings":
    if mode == "leaked-path": print("/Users/private/source/main.cj")
    if mode == "debug-marker": print("CANGHUI_PRIVILEGED_DEBUG_BUILD=1")
    if mode == "transport-marker": print("CANGHUI_KMODE_TRANSPORT")
elif name == "nm":
    print("0000000000000100 T _main")
elif name == "otool":
    print(args[-1] + ":")
    if args[0] == "-L":
        if mode == "malformed-dependencies": print("not-a-dependency")
        elif mode != "empty-dependencies":
            print("\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1.0.0)")
    elif args[0] == "-l":
        print("Load command 0\n      cmd LC_RPATH\n  cmdsize 56")
        if mode != "missing-rpath-value":
            print("     path @executable_path/../Frameworks (offset 12)")
elif name == "find":
    root = args[0]
    for parent, dirs, files in os.walk(root):
        for filename in files:
            sys.stdout.buffer.write(os.fsencode(os.path.join(parent, filename)) + b"\0")
    if mode == "partial-inventory": sys.exit(41)
elif name == "shasum":
    print("0" * 64 + "  " + args[-1])
'''


class MacReleaseAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="chui audit policy ")
        self.root = Path(self.temp.name)
        self.app = self.root / "Example.app"
        binary = self.app / "Contents/MacOS/example"
        binary.parent.mkdir(parents=True)
        binary.write_bytes(b"test fixture, native inspectors are mocked")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("file", "codesign", "strings", "nm", "otool", "find", "shasum", "spctl", "xcrun"):
            tool = self.bin / name
            tool.write_text(SHIM, encoding="utf-8")
            tool.chmod(0o755)
        # Keep Python available even when the caller uses a minimal PATH.
        (self.bin / "python3").symlink_to(sys.executable)

    def tearDown(self):
        self.temp.cleanup()

    def audit(self, failure="", limit=None, mode="candidate"):
        env = dict(os.environ)
        env.pop("CANGHUI_MAX_RELEASE_SYMBOLS", None)
        env["PATH"] = str(self.bin) + os.pathsep + env.get("PATH", "/usr/bin:/bin")
        env["AUDIT_TEST_FAILURE"] = failure
        if limit is not None:
            env["CANGHUI_MAX_RELEASE_SYMBOLS"] = limit
        return subprocess.run([shutil.which("bash"), str(SCRIPT), "--" + mode, str(self.app)],
                              env=env, text=True, capture_output=True, check=False)

    def test_valid_candidate(self):
        result = self.audit()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("audit passed", result.stdout)

    def test_failed_inspection_is_not_clean_evidence(self):
        for failure in ("file", "strings", "nm", "otool:-L", "otool:-l", "find", "partial-inventory", "shasum"):
            with self.subTest(failure=failure):
                result = self.audit(failure)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn("audit passed", result.stdout)

    def test_missing_or_malformed_dependency_and_rpath_evidence(self):
        for failure in ("empty-dependencies", "malformed-dependencies", "missing-rpath-value"):
            with self.subTest(failure=failure):
                result = self.audit(failure)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_invalid_symbol_limit_is_not_a_bypass(self):
        for limit in ("garbage", "-1", "1+100000", "08", "999999999999999999999999999", ""):
            with self.subTest(limit=limit):
                result = self.audit(limit=limit)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn("audit passed", result.stdout)

    def test_actual_policy_violation_is_still_rejected(self):
        result = self.audit("leaked-path")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("absolute developer/workspace path", result.stderr)

    def test_candidate_only_accepts_known_unsigned_state(self):
        result = self.audit("unsigned")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for failure in ("codesign", "metadata-failure", "entitlements-failure", "empty-classification"):
            with self.subTest(failure=failure):
                result = self.audit(failure)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_publisher_and_privilege_gates_are_not_weakened(self):
        result = self.audit("unsigned", mode="publisher")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot read code signature metadata", result.stderr)
        for failure in ("debug-marker", "transport-marker"):
            with self.subTest(failure=failure):
                self.assertNotEqual(self.audit(failure).returncode, 0)

    def test_numeric_symbol_limit_is_enforced(self):
        self.assertNotEqual(self.audit(limit="0").returncode, 0)
        self.assertEqual(self.audit(limit="1").returncode, 0)


if __name__ == "__main__":
    unittest.main()
