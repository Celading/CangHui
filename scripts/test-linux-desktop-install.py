#!/usr/bin/env python3
"""Portable admission guards for the opt-in native acceptance helper."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('desktop_acceptance', Path(__file__).with_name('verify-linux-desktop-install.py'))
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / 'bundle'
        self.bundle.mkdir()
        self.output = self.root / 'new evidence'
        self.receipt = {'platform': 'linux', 'executableIncluded': True,
                        'identity': {'identifier': 'dev.test', 'name': 'Test'}}
        self.save()

    def save(self):
        (self.bundle / 'canghui-packaging-receipt.json').write_text(json.dumps(self.receipt))

    def verify(self):
        with patch.object(desktop.sys, 'platform', 'linux'):
            desktop.verify(self.bundle, self.output)

    def test_nonlinux_host_stops_before_output(self):
        with patch.object(desktop.sys, 'platform', 'darwin'), self.assertRaisesRegex(ValueError, 'requires Linux'):
            desktop.verify(self.bundle, self.output)
        self.assertFalse(self.output.exists())

    def test_metadata_tree_is_not_a_runtime(self):
        self.receipt['executableIncluded'] = False
        self.save()
        with self.assertRaisesRegex(ValueError, 'real CUIC'):
            self.verify()
        self.assertFalse(self.output.exists())

    def test_identifier_cannot_escape_prefix(self):
        self.receipt['identity']['identifier'] = '../other'
        self.save()
        with self.assertRaisesRegex(ValueError, 'unsafe'):
            self.verify()
        self.assertFalse(self.output.exists())

    def test_symlink_tree_is_not_copied(self):
        (self.bundle / 'link').symlink_to(self.root)
        with self.assertRaisesRegex(ValueError, 'regular bundle'):
            self.verify()
        self.assertFalse(self.output.exists())

    @unittest.skipUnless(hasattr(os, 'mkfifo'), 'POSIX file type control')
    def test_receipt_fifo_is_rejected_before_read(self):
        receipt = self.bundle / 'canghui-packaging-receipt.json'
        receipt.unlink()
        os.mkfifo(receipt)
        with self.assertRaisesRegex(ValueError, 'regular packaging receipt'):
            self.verify()
        self.assertFalse(self.output.exists())

    @unittest.skipUnless(hasattr(os, 'mkfifo'), 'POSIX file type control')
    def test_special_file_is_not_opened_or_copied(self):
        os.mkfifo(self.bundle / 'pipe')
        with self.assertRaisesRegex(ValueError, 'regular bundle'):
            self.verify()
        self.assertFalse(self.output.exists())

    def test_existing_output_and_symlink_are_not_overwritten(self):
        self.output.mkdir()
        marker = self.output / 'keep'
        marker.write_text('unchanged')
        with self.assertRaises(FileExistsError):
            self.verify()
        self.assertEqual(marker.read_text(), 'unchanged')
        link = self.root / 'output-link'
        link.symlink_to(self.output, target_is_directory=True)
        with patch.object(desktop.sys, 'platform', 'linux'), self.assertRaises(FileExistsError):
            desktop.verify(self.bundle, link)
        self.assertEqual(marker.read_text(), 'unchanged')


if __name__ == '__main__':
    unittest.main()
