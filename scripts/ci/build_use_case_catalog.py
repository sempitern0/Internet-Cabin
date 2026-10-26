#!/usr/bin/env python3
"""Generate the human-readable catalog from the single JSON routing registry."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

from console_report import ConsoleReport, add_console_arguments


def render(registry: dict) -> str:
    grouped: dict[str, list[dict]] = defaultdict(list)
    for item in registry["cases"]:
        grouped[item["domain"]].append(item)
    total = len(registry["cases"])
    lines = [
        "# Game Development Use Cases", "",
        f"**{total} game-development scenarios · five capability areas · one source of truth**", "",
        "> [!TIP]",
        "> **Start with the feature you want.** Find its row, follow the existing",
        "> Nucleus contract, and implement only the game-specific rules that remain.", "",
        "**Browse:** [Core](#core) · [Gameplay](#gameplay) · [UI](#ui) ·",
        "[World](#world) · [Optional modules](#optional-modules)", "",
        "## How to use this catalog", "",
        "1. Find the closest player or developer problem below.",
        "2. Open the linked technical contract and verify its current script API.",
        "3. Read a quickstart or tutorial to wire a minimal scene.",
        "4. Keep gameplay logic and content in the consuming game.",
        "5. Run the relevant tests and verify the behavior in a real scene.", "",
        "> [!IMPORTANT]",
        "> **Ownership boundary:** Godot owns engine primitives; Nucleus provides",
        "> reusable contracts; the game owns rules, content, balance, and visuals.", "",
        "**More help:** [AI/human workflow](ai_composition_workflow.md) ·",
        "[Composition recipes](composition_recipes.md) ·",
        "[Ownership decisions](../architecture/component_selection.md) ·",
        "[Machine-readable registry](../use_case_registry.json)", "",
    ]
    icons = {
        "Core": "🟦", "Gameplay": "🟩", "UI": "🟪",
        "World": "🟨", "Optional modules": "🟧",
    }
    for domain, cases in grouped.items():
        lines.extend([
            f"## {icons.get(domain, '▪')} {domain}", "",
            "| What you want to build | Reuse this contract | The game still decides |",
            "| --- | --- | --- |",
        ])
        for item in cases:
            mechanism = item["nucleus_role"].replace("|", "/")
            route = "../" + item["guide"].removeprefix("docs/")
            lines.append(
                f"| {item['need']} | [{mechanism}]({route}) | {item['game_owns']} |"
            )
        lines.append("")
    lines.extend([
        "## Limits and guardrails", "",
        "> [!WARNING]",
        "> **Use the listed owner; do not assume a finished game mechanic.**",
        "> Add your own rules, test real gameplay, and keep trust decisions server-side.", "",
        "- A component is not a finished RPG/MMO/survival/puzzle mechanic; the game wires inputs, state and feedback.",
        "- A valid API call is not a trust decision; authoritative worlds validate requests and visibility.",
        "- A smoke/headless test is not proof of feel, visuals, latency or frame budget on real hardware.",
        "- Generic tools should not replace Godot physics, animation, navigation or UndoRedo.",
        "- Do not add a global manager merely to make a generated mechanic easier to access.", "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--check", action="store_true")
    add_console_arguments(parser)
    args = parser.parse_args()
    root = args.root.resolve()
    report = ConsoleReport("Use-case catalog", args)
    registry_path = root / "docs/use_case_registry.json"
    try:
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
        expected = render(registry)
    except (OSError, UnicodeError, ValueError, KeyError, TypeError) as exc:
        return report.finish([f"cannot build catalog: {exc}"])

    output = root / "docs/guides/use_case_catalog.md"
    report.metric("Registry", str(registry_path.relative_to(root)))
    report.metric("Routes", f"{len(registry['cases'])} catalog entries")
    report.metric("Output", str(output.relative_to(root)))
    report.metric("Mode", "Read-only comparison" if args.check else "Generate file")
    if args.check:
        if not output.is_file() or output.read_text(encoding="utf-8") != expected:
            return report.finish([
                "Use-case catalog: OUT OF DATE; run build_use_case_catalog.py"
            ])
        report.hint("Catalog matches the current routing registry.")
        return report.finish([])
    output.write_text(expected, encoding="utf-8")
    report.metric("Written", f"{len(expected.encode('utf-8'))} bytes")
    return report.finish([])


if __name__ == "__main__":
    raise SystemExit(main())
