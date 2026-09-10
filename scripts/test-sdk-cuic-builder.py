#!/usr/bin/env python3
"""Policy-only checks; actual SDK consumption remains a separate native gate."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("sdk", Path(__file__).with_name("build-source-sdk.py"))
sdk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sdk)


class CuicBuilderTests(unittest.TestCase):
    def test_explicit_bootstrap_must_be_an_executable_file(self):
        self.assertIsNone(sdk.resolve_bootstrap_cuic(None))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "cuic with spaces"
            with self.assertRaises(FileNotFoundError):
                sdk.resolve_bootstrap_cuic(path)
            with self.assertRaises(ValueError):
                sdk.resolve_bootstrap_cuic(Path(directory))
            path.write_text("fixture, never executed")
            path.chmod(0o600)
            with self.assertRaises(ValueError):
                sdk.resolve_bootstrap_cuic(path)
            path.chmod(0o700)
            self.assertEqual(sdk.resolve_bootstrap_cuic(path), path.resolve())

    def replay(self, system, fail=False):
        revision = "a" * 40
        commands = []
        verified = []
        def export(actual, paths, staging):
            self.assertEqual(actual, revision)
            self.assertEqual(paths, sdk.SOURCE_ROOTS + ["tools/cuic"])
            cli = staging / "tools/cuic"
            (cli / "src").mkdir(parents=True)
            (cli / "cjpm.toml").write_text('version = "0.6.0"\ncompile-option = "--static"\n')
        def build(command, cwd, check, env):
            self.assertTrue(check)
            self.assertEqual(command, ["/fixture/cuic with spaces", "build",
                             "macos" if system == "Darwin" else "linux", str(cwd),
                             "--mode", "release" if not commands else "debug"])
            self.assertEqual(env["CANGHUI_CLI_ROOT"], str(cwd))
            self.assertEqual(env["CUIC_TARGET_DIR"], str(cwd / "target"))
            self.assertIn(revision, (cwd / "src/build_identity.cj").read_text())
            commands.append(command)
            if fail:
                raise subprocess.CalledProcessError(7, command)
            binary = cwd / "target" / command[-1] / "bin/main"
            binary.parent.mkdir(parents=True)
            binary.write_text(command[-1])
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(sdk, "export_revision", side_effect=export), \
                patch.object(sdk.subprocess, "run", side_effect=build), \
                patch.object(sdk, "run", return_value="fixture version"), \
                patch.object(sdk.platform, "system", return_value=system), \
                patch.dict(os.environ, {"CANGHUI_CLI_ROOT": "/unrelated/source", "CUIC_TARGET_DIR": "/unrelated/target"}):
            action = lambda: sdk.build_cli_pair(Path(directory), revision,
                lambda path: verified.append((path.name, path.read_text())), cuic=Path("/fixture/cuic with spaces"))
            if fail:
                with self.assertRaises(subprocess.CalledProcessError):
                    action()
                self.assertEqual(len(commands), 1)  # no raw-CJPM fallback
                self.assertEqual(verified, [])
            else:
                self.assertEqual(action(), "0.6.0")
                self.assertEqual(verified, [("cuic", "release"), ("cuic-debug", "debug")])
            self.assertEqual(os.environ["CANGHUI_CLI_ROOT"], "/unrelated/source")
            self.assertEqual(os.environ["CUIC_TARGET_DIR"], "/unrelated/target")

    def test_cuic_pair_keeps_exact_revision_scoped_environment_and_target_modes(self):
        for system in ("Darwin", "Linux"):
            with self.subTest(system=system):
                self.replay(system)

    def test_failed_cuic_never_falls_back_to_cjpm_or_publishes_a_binary(self):
        self.replay("Linux", fail=True)


if __name__ == "__main__":
    unittest.main()
