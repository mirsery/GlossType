import os
import plistlib
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLIST = ROOT / "Packaging" / "Info.plist"
PACKAGE = ROOT / "scripts" / "package_app.sh"


def load_plist():
    with open(PLIST, "rb") as handle:
        return plistlib.load(handle)


class InfoPlistTests(unittest.TestCase):
    def test_install_01_info_plist_has_input_method_keys(self):
        info = load_plist()
        for key in (
            "InputMethodConnectionName",
            "InputMethodServerControllerClass",
            "tsInputMethodCharacterRepertoireKey",
            "tsInputMethodIconFileKey",
        ):
            self.assertTrue(info.get(key), key)
        self.assertIs(info.get("LSUIElement"), True)
        self.assertEqual(info.get("LSMinimumSystemVersion"), "15.0")
        self.assertTrue((ROOT / "Packaging" / info["tsInputMethodIconFileKey"]).exists())

    def test_install_02_controller_class_matches_objc_name(self):
        info = load_plist()
        names = set()
        for source in (ROOT / "Sources" / "GlossTypeApp").glob("*.swift"):
            text = source.read_text(encoding="utf-8")
            names.update(re.findall(r"@objc\((\w+)\)\s*(?:final\s+)?class\s+\w+\s*:\s*IMKInputController", text))
        self.assertEqual(names, {info["InputMethodServerControllerClass"]})

    def test_install_03_bundle_id_contains_inputmethod(self):
        self.assertIn(".inputmethod.", load_plist()["CFBundleIdentifier"])


class PackageScriptTests(unittest.TestCase):
    def run_package(self, with_glossary):
        work = Path(tempfile.mkdtemp())
        binary = work / "GlossType"
        binary.write_bytes(b"#!/bin/sh\n")
        data = work / "Data"
        data.mkdir()
        if with_glossary:
            (data / "glossary.sqlite").write_bytes(b"sqlite")
        app = work / "GlossType.app"
        env = dict(os.environ, SKIP_CODESIGN="1")
        result = subprocess.run(
            ["bash", str(PACKAGE), str(binary), str(app), str(data)],
            capture_output=True, text=True, env=env,
        )
        return result, app

    def test_install_04_package_script_assembles_bundle(self):
        result, app = self.run_package(with_glossary=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for relative in (
            "Contents/MacOS/GlossType",
            "Contents/Info.plist",
            "Contents/Resources/GlossType.pdf",
            "Contents/Resources/glossary.sqlite",
        ):
            self.assertTrue((app / relative).exists(), relative)
        self.assertTrue(os.access(app / "Contents/MacOS/GlossType", os.X_OK))

    def test_install_05_package_script_requires_glossary(self):
        result, _ = self.run_package(with_glossary=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("make data", result.stderr)


if __name__ == "__main__":
    unittest.main()
