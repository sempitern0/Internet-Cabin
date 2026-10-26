#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
REPOSITORY_ROOT="${1:-$PWD}"
BUILD_ROOT="${BUILD_ROOT:-$REPOSITORY_ROOT/build/smoke}"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

project_copy="$tmp_root/Nucleus"
mkdir -p "$project_copy"

(
	cd "$REPOSITORY_ROOT"
	tar \
		--exclude='.git' \
		--exclude='.godot' \
		--exclude='.ci' \
		--exclude='build' \
		-cf - .
) | (
	cd "$project_copy"
	tar -xf -
)

python3 "$project_copy/scripts/ci/prepare_smoke_project.py" \
	"$project_copy/project.godot"

cp \
	"$project_copy/scripts/ci/smoke_export_presets.cfg" \
	"$project_copy/export_presets.cfg"

mkdir -p \
	"$BUILD_ROOT/linux" \
	"$BUILD_ROOT/windows" \
	"$BUILD_ROOT/web"

"$GODOT_BIN" --headless --path "$project_copy" \
	--export-release "Nucleus Linux Smoke" \
	"$BUILD_ROOT/linux/nucleus-smoke.x86_64"

"$GODOT_BIN" --headless --path "$project_copy" \
	--export-release "Nucleus Windows Smoke" \
	"$BUILD_ROOT/windows/nucleus-smoke.exe"

"$GODOT_BIN" --headless --path "$project_copy" \
	--export-release "Nucleus Web Smoke" \
	"$BUILD_ROOT/web/nucleus-smoke.zip"

test -s "$BUILD_ROOT/linux/nucleus-smoke.x86_64"
test -s "$BUILD_ROOT/windows/nucleus-smoke.exe"
test -s "$BUILD_ROOT/web/nucleus-smoke.zip"

echo "Nucleus smoke exports: PASS"
