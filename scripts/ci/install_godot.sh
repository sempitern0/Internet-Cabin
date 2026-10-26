#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2-stable}"
GODOT_INSTALL_EXPORT_TEMPLATES="${GODOT_INSTALL_EXPORT_TEMPLATES:-1}"
CACHE_ROOT="${GODOT_CACHE_ROOT:-$PWD/.ci/godot}"
BIN_DIR="$CACHE_ROOT/bin"
DOWNLOAD_DIR="$CACHE_ROOT/downloads"
TEMPLATE_VERSION="${GODOT_VERSION/-stable/.stable}"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/$TEMPLATE_VERSION"

mkdir -p "$BIN_DIR" "$DOWNLOAD_DIR"

BASE_URL="https://github.com/godotengine/godot-builds/releases/download/$GODOT_VERSION"
ENGINE_ARCHIVE="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
TEMPLATE_ARCHIVE="Godot_v${GODOT_VERSION}_export_templates.tpz"
ENGINE_PATH="$BIN_DIR/godot"

if [[ ! -x "$ENGINE_PATH" ]]; then
	curl --fail --location --retry 3 \
		"$BASE_URL/$ENGINE_ARCHIVE" \
		--output "$DOWNLOAD_DIR/$ENGINE_ARCHIVE"
	unzip -q -o "$DOWNLOAD_DIR/$ENGINE_ARCHIVE" -d "$BIN_DIR"

	found_engine="$(
		find "$BIN_DIR" -maxdepth 1 -type f -name 'Godot*_linux.x86_64' -print -quit
	)"
	[[ -n "$found_engine" ]] || {
		echo "Unable to locate the Godot editor binary." >&2
		exit 1
	}

	mv "$found_engine" "$ENGINE_PATH"
	chmod +x "$ENGINE_PATH"
fi

if [[ "$GODOT_INSTALL_EXPORT_TEMPLATES" != "0" ]]; then
	mkdir -p "$TEMPLATE_DIR"

	if [[ ! -f "$TEMPLATE_DIR/version.txt" ]]; then
		curl --fail --location --retry 3 \
			"$BASE_URL/$TEMPLATE_ARCHIVE" \
			--output "$DOWNLOAD_DIR/$TEMPLATE_ARCHIVE"

		template_stage="$(mktemp -d)"
		trap 'rm -rf "$template_stage"' EXIT
		unzip -q -o "$DOWNLOAD_DIR/$TEMPLATE_ARCHIVE" -d "$template_stage"

		template_source="$template_stage/templates"
		[[ -d "$template_source" ]] || {
			echo "Unable to locate export templates in archive." >&2
			exit 1
		}

		rm -rf "$TEMPLATE_DIR"
		mkdir -p "$TEMPLATE_DIR"
		cp -a "$template_source"/. "$TEMPLATE_DIR"/
		printf '%s\n' "$GODOT_VERSION" > "$TEMPLATE_DIR/version.txt"
	fi
fi

printf '%s\n' "$ENGINE_PATH"
