#!/usr/bin/env python3
"""Check canonical 4:3 adventure artwork using only the Python standard library."""
from pathlib import Path
import argparse
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "assets" / "cabin"
FILES = (
    "cabin_base.png", "cabin_base_open_door.png", "cabin_back.png",
    "cabin_bed.png", "computer.png", "computer_side_window.png",
    "cabin_closed_door.png", "cabin_open_door.png",
    "bed_close.png", "bed_windows.png", "entry_picture.png",
    "desktop_tower.png", "computer_screen.png", "cabin_shelf.png",
    "cabin_clothes.png", "cabin_boots.png",
)
DOORS = {"cabin_closed_door.png", "cabin_open_door.png"}
EXPECTED = (1448, 1086)


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        data = handle.read(24)
    if len(data) != 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("not a valid PNG header")
    return struct.unpack(">II", data[16:24])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-missing-door", action="store_true")
    args = parser.parse_args()
    failures = []
    for filename in FILES:
        path = DIR / filename
        if not path.is_file():
            if not (args.allow_missing_door and filename in DOORS):
                failures.append(f"{filename}: missing")
            continue
        try:
            dimensions = png_size(path)
        except (ValueError, OSError) as error:
            failures.append(f"{filename}: {error}")
            continue
        if dimensions != EXPECTED:
            failures.append(f"{filename}: {dimensions}, expected {EXPECTED}")
        else:
            print(f"OK {filename}: {dimensions[0]} x {dimensions[1]}")
    for failure in failures:
        print("ERROR", failure, file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
