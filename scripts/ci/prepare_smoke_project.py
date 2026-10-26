#!/usr/bin/env python3
"""Set the smoke scene as main scene in a disposable project copy."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("project_file", type=Path)
	args = parser.parse_args()

	text = args.project_file.read_text(encoding="utf-8")
	marker = '[application]\n'

	if marker not in text:
		raise SystemExit("project.godot has no [application] section")

	entry = 'run/main_scene="res://tests/smoke/smoke_main.tscn"\n'

	if "run/main_scene=" in text:
		lines = text.splitlines()
		lines = [
			entry.rstrip("\n") if line.startswith("run/main_scene=") else line
			for line in lines
		]
		text = "\n".join(lines) + "\n"
	else:
		text = text.replace(marker, marker + "\n" + entry, 1)

	args.project_file.write_text(text, encoding="utf-8", newline="\n")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
