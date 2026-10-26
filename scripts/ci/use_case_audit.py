#!/usr/bin/env python3
"""Audit Nucleus's behavior-first guide registry using only the stdlib."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from console_report import ConsoleReport, add_console_arguments

REGISTRY = Path("docs/use_case_registry.json")
REQUIRED_DOMAINS = frozenset({
    "Core", "Gameplay", "UI", "World", "Optional modules"
})
REQUIRED_GUIDES = (
    "docs/guides/use_case_catalog.md",
    "docs/guides/ai_composition_workflow.md",
    "docs/guides/composition_recipes.md",
    "docs/architecture/component_selection.md",
)
MARKDOWN_LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
# English is the repository documentation language.
BILINGUAL_HEADING = re.compile(r"(?im)^#{1,6}[^\n]*casos\s+de\s+uso")


def audit(root: Path) -> list[str]:
    """Return errors; never execute resources or import game scripts."""
    errors: list[str] = []
    registry_file = root / REGISTRY
    if not registry_file.is_file():
        return [f"missing registry: {REGISTRY}"]
    try:
        data = json.loads(registry_file.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as exc:
        return [f"invalid registry: {exc}"]
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        return ["registry schema_version must be 1"]
    cases = data.get("cases")
    if not isinstance(cases, list) or not cases:
        return ["registry must contain a nonempty cases list"]
    domains: set[str] = set()
    keys: set[tuple[str, str]] = set()
    for index, case in enumerate(cases):
        if not isinstance(case, dict):
            errors.append(f"cases[{index}]: expected an object")
            continue
        required = ("domain", "need", "nucleus_role", "guide", "game_owns")
        for field in required:
            value = case.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"cases[{index}]: empty or invalid {field}")
        if any(not isinstance(case.get(f), str) for f in required):
            continue
        domain = case["domain"].strip()
        need = case["need"].strip()
        guide = case["guide"]
        domains.add(domain)
        key = (domain.casefold(), need.casefold())
        if key in keys:
            errors.append(f"cases[{index}]: duplicate use case {domain}/{need}")
        keys.add(key)
        if not guide.startswith("docs/") or not guide.endswith(".md"):
            errors.append(f"cases[{index}]: guide must be a docs/ Markdown path")
        elif (root / guide).is_file() is False:
            errors.append(f"cases[{index}]: missing guide {guide}")
    for missing in sorted(REQUIRED_DOMAINS - domains):
        errors.append(f"missing domain: {missing}")
    for relative in REQUIRED_GUIDES:
        if not (root / relative).is_file():
            errors.append(f"missing discovery guide: {relative}")
    # Check every repository-local relative Markdown link in the discovery guides.
    # Anchors and external links remain the responsibility of their destination.
    for relative in REQUIRED_GUIDES:
        page = root / relative
        if not page.is_file():
            continue
        text = page.read_text(encoding="utf-8")
        if BILINGUAL_HEADING.search(text):
            errors.append(f"{relative}: bilingual section heading; use English only")
        for uri in MARKDOWN_LINK.findall(text):
            path_part = uri.split("#", 1)[0].strip()
            if not path_part or path_part.startswith(("https:", "http:", "mailto:")):
                continue
            if path_part.startswith("res://") or path_part.startswith("/"):
                errors.append(f"{relative}: unsupported Markdown link {uri}")
                continue
            resolved = (page.parent / path_part).resolve()
            if not resolved.is_relative_to(root.resolve()):
                errors.append(f"{relative}: link escapes repository: {uri}")
            elif not resolved.is_file():
                errors.append(f"{relative}: broken link {uri}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    add_console_arguments(parser)
    args = parser.parse_args()
    root = args.root.resolve()
    report = ConsoleReport("Use-case routing and links", args)
    errors = audit(root)

    cases: list = []
    registry_file = root / REGISTRY
    if registry_file.is_file():
        try:
            data = json.loads(registry_file.read_text(encoding="utf-8"))
            if isinstance(data, dict) and isinstance(data.get("cases"), list):
                cases = data["cases"]
        except (OSError, UnicodeError, ValueError):
            pass
    domains = Counter(
        case.get("domain") for case in cases
        if isinstance(case, dict) and isinstance(case.get("domain"), str)
    )
    report.metric("Registry", f"{len(cases)} use cases across {len(domains)} domains")
    report.fraction("Required domains", len(REQUIRED_DOMAINS & domains.keys()), len(REQUIRED_DOMAINS))
    for domain in sorted(REQUIRED_DOMAINS):
        report.metric(f"  {domain}", f"{domains.get(domain, 0)} routes")
    report.metric("Discovery guides", f"{len(REQUIRED_GUIDES)} files + local Markdown links")
    report.hint("Run build_use_case_catalog.py --check to catch generated-catalog drift.")
    return report.finish(errors)


if __name__ == "__main__":
    raise SystemExit(main())
