#!/usr/bin/env python3
"""Small, dependency-free console presentation for Nucleus CLI checks.

This module formats results; it never decides whether an audit passes.
Color is opt-in on non-TTY streams and disabled automatically in CI/NO_COLOR.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from typing import Sequence


def add_console_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--verbose", action="store_true",
        help="Show a detailed summary even in CI/non-interactive environments.",
    )
    parser.add_argument(
        "--quiet", action="store_true",
        help="Only print the final result and errors.",
    )
    parser.add_argument(
        "--color", choices=("auto", "always", "never"), default="auto",
        help="ANSI output color: auto only on an interactive terminal (default).",
    )


def _ansi_allowed(mode: str) -> bool:
    if mode == "never" or os.getenv("NO_COLOR") is not None:
        return False
    if mode == "always":
        return True
    return bool(sys.stdout.isatty() and not os.getenv("CI") and os.getenv("TERM") != "dumb")


def _unicode_allowed() -> bool:
    encoding = sys.stdout.encoding or "utf-8"
    try:
        "✓─".encode(encoding)
        return True
    except UnicodeEncodeError:
        return False


class ConsoleReport:
    """Collect display-only facts, then print a stable pass/fail summary."""

    def __init__(self, title: str, args: argparse.Namespace):
        self.title = title
        self.started = time.perf_counter()
        self.color = _ansi_allowed(getattr(args, "color", "auto"))
        self.quiet = getattr(args, "quiet", False)
        self.detailed = (getattr(args, "verbose", False) or not os.getenv("CI")) and not self.quiet
        self.lines: list[tuple[str, str]] = []
        self.hints: list[str] = []
        self.unicode = _unicode_allowed()

    def metric(self, name: str, detail: object) -> None:
        self.lines.append((str(name), str(detail)))

    def fraction(self, label: str, numerator: int, denominator: int) -> None:
        """Display a bounded bar using actual measured counts (never simulated)."""
        percent = numerator / denominator if denominator > 0 else 0.0
        width = 18
        filled = round(width * max(0.0, min(1.0, percent)))
        bar = "#" * filled + "." * (width - filled)
        self.metric(label, f"[{bar}] {numerator}/{denominator} ({percent:.0%})")

    def hint(self, message: str) -> None:
        self.hints.append(message)

    def _paint(self, text: str, color: str) -> str:
        if not self.color:
            return text
        codes = {"green": "32", "red": "31", "yellow": "33", "cyan": "36", "dim": "2"}
        return f"\x1b[{codes[color]}m{text}\x1b[0m"

    def finish(self, errors: Sequence[str], *, note: str = "", warnings: int = 0) -> int:
        elapsed = time.perf_counter() - self.started
        raw_status = "FAIL" if errors else ("WARN" if warnings else "PASS")
        color = "red" if errors else ("yellow" if warnings else "green")
        status = self._paint(raw_status, color)
        duration = f"{elapsed:.2f}s"
        bullet = "•" if self.unicode else "-"
        rule = "─" * 64 if self.unicode else "-" * 64

        if self.detailed:
            print(f"\n{self._paint('NUCLEUS', 'cyan')}  /  {self.title}")
            print(self._paint(rule, "dim"))
            width = max((len(label) for label, _ in self.lines), default=10)
            for label, detail in self.lines:
                print(f"  {bullet} {label:<{width}}  {detail}")
            if note:
                print(f"  {bullet} Note{' ' * max(width - 4, 0)}  {note}")
            print(self._paint(rule, "dim"))
            print(f"  {status}   {len(errors)} blocking issue(s) / {warnings} warnings  /  {duration}")
            if not errors:
                for hint in self.hints:
                    print(f"  {self._paint('NEXT', 'cyan')}  {hint}")
        else:
            summary = f"{self.title}: {status} ({len(errors)} blocking issue(s), {warnings} warnings, {duration})"
            if note:
                summary += f"; {note}"
            print(summary)

        if errors:
            print(f"\n  {self._paint('ISSUES', 'red')}  ({len(errors)})")
            # Interactive output stays navigable; CI prints everything.
            cap = None if os.getenv("CI") or not self.detailed else 40
            for error in errors[:cap]:
                print(f"  {bullet} {error}")
            if cap is not None and len(errors) > cap:
                print(f"  ... {len(errors) - cap} more; use CI=1 or --quiet to print all")
        return 1 if errors else 0

