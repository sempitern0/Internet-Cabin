#!/usr/bin/env python3
"""Dependency-free unit tests for the opt-in security preflight."""
from pathlib import Path
import tempfile
import unittest

from audit_game_exports import audit_file


class GameExportAuditTests(unittest.TestCase):
    def audit(self, content: str, profile: str = "standard", preset: str | None = None):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "export_presets.cfg"
            p.write_text(content, encoding="utf-8")
            return audit_file(p, profile, preset)

    @staticmethod
    def codes(findings):
        return {f["code"] for f in findings}

    def test_template_without_presets_warns_not_crashes(self):
        self.assertIn("NO_PRESETS", self.codes(audit_file(Path("/never-a-real-dir") / "export_presets.cfg", "standard")))

    def test_hardened_windows_findings(self):
        lines = '[preset.0]\nname="Release Windows"\nplatform="Windows Desktop"\nencrypt_pck=false\n[preset.0.options]\ncodesign/enable=false\n'
        self.assertTrue({"PCK_NOT_ENCRYPTED", "WINDOWS_SIGNING_OFF"}.issubset(self.codes(self.audit(lines, "hardened"))))

    def test_encryption_requires_filters_and_templates(self):
        lines = '[preset.0]\nname="R"\nplatform="Linux"\nencrypt_pck=true\nencryption_include_filters=""\n[preset.0.options]\n'
        self.assertTrue({"EMPTY_ENCRYPTION_FILTERS", "NO_CUSTOM_RELEASE_TEMPLATE"}.issubset(self.codes(self.audit(lines))))

    def test_secret_redacted_from_output(self):
        secret = 'dont-display-this-value-123'
        lines = f'[preset.0]\nname="R"\nplatform="Windows Desktop"\nscript_encryption_key="{secret}"\n[preset.0.options]\n'
        findings = self.audit(lines)
        self.assertIn("POSSIBLE_SECRET_IN_PRESET", self.codes(findings))
        self.assertNotIn(secret, str(findings))

    def test_preset_filter(self):
        lines = '[preset.0]\nname="A"\nplatform="Linux"\n[preset.0.options]\n\n[preset.1]\nname="B"\nplatform="Windows Desktop"\n[preset.1.options]\n'
        findings = self.audit(lines, preset="A")
        self.assertNotIn("WINDOWS_SIGNING_OFF", self.codes(findings))
        self.assertIn("PRESET_NOT_FOUND", self.codes(self.audit(lines, preset="C")))

    def test_encrypted_valid_intent_is_not_proof(self):
        lines = ('[preset.0]\nname="Windows"\nplatform="Windows Desktop"\nencrypt_pck=true\n'
                 'encryption_include_filters="*.gd,*.tscn"\n[preset.0.options]\n'
                 'custom_template/release="custom.exe"\ncodesign/enable=true\n')
        codes = self.codes(self.audit(lines, "hardened"))
        self.assertNotIn("NO_CUSTOM_RELEASE_TEMPLATE", codes)
        self.assertNotIn("EMPTY_ENCRYPTION_FILTERS", codes)
        self.assertIn("RUNTIME_NOT_VERIFIED", codes)


if __name__ == "__main__":
    unittest.main()
