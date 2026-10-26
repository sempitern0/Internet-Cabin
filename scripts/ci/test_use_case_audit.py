#!/usr/bin/env python3
"""Pure Python regressions for use_case_audit (run with unittest)."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from use_case_audit import REQUIRED_GUIDES, audit


class UseCaseAuditTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for path in REQUIRED_GUIDES:
            page = self.root / path
            page.parent.mkdir(parents=True, exist_ok=True)
            page.write_text("# A guide\n", encoding="utf-8")
        self.registry = self.root / "docs/use_case_registry.json"
        self.registry.parent.mkdir(parents=True, exist_ok=True)
        self.data = {
            "schema_version": 1,
            "cases": [],
        }
        for domain in ("Core", "Gameplay", "UI", "World", "Optional modules"):
            self.data["cases"].append({
                "domain": domain,
                "need": "An example " + domain,
                "nucleus_role": "Example owner",
                "guide": REQUIRED_GUIDES[0],
                "game_owns": "Example content",
            })
        self.save()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def save(self) -> None:
        self.registry.write_text(json.dumps(self.data), encoding="utf-8")

    def test_valid_registry(self) -> None:
        self.assertEqual(audit(self.root), [])

    def test_missing_document(self) -> None:
        self.data["cases"][0]["guide"] = "docs/missing.md"
        self.save()
        self.assertTrue(any("missing guide" in e for e in audit(self.root)))

    def test_duplicate_case(self) -> None:
        self.data["cases"].append(dict(self.data["cases"][0]))
        self.save()
        self.assertTrue(any("duplicate use case" in e for e in audit(self.root)))

    def test_broken_markdown_link(self) -> None:
        page = self.root / REQUIRED_GUIDES[0]
        page.write_text("# Test\n[bad](../../missing.md)\n", encoding="utf-8")
        self.assertTrue(any("broken link" in e for e in audit(self.root)))

    def test_catalog_has_single_language_and_visual_routes(self) -> None:
        from build_use_case_catalog import render
        text = render(self.data)
        self.assertIn("# Game Development Use Cases", text)
        self.assertIn("> [!TIP]", text)
        self.assertIn("> [!IMPORTANT]", text)
        self.assertIn("🟩 Gameplay", text)
        self.assertNotIn("casos" + " de uso", text.lower())

    def test_reject_bilingual_heading(self) -> None:
        page = self.root / REQUIRED_GUIDES[0]
        page.write_text("# Example\n## Use cases / " + "Casos" + " de uso\n", encoding="utf-8")
        self.assertTrue(any("bilingual section heading" in e for e in audit(self.root)))

    def test_reject_non_docs_route(self) -> None:
        self.data["cases"][0]["guide"] = "https://example.org/intro"
        self.save()
        self.assertTrue(any("must be a docs/ Markdown" in e for e in audit(self.root)))


if __name__ == "__main__":
    unittest.main()
