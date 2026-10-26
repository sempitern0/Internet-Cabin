#!/usr/bin/env python3
"""Opt-in, read-only Godot game export-preset security preflight.

This checks configuration intent, not exported binary integrity, cert validity,
PCK key management, or runtime behavior. It never opens Godot credentials files.
Designed for a consuming game's release job, NOT Nucleus baseline smoke CI.
"""

from __future__ import annotations

import argparse
import configparser
import json
from pathlib import Path
import re
import sys

from console_report import ConsoleReport, add_console_arguments

SENSITIVE_OPTION_PATTERNS = (
    "script_encryption_key",
    "codesign/password",
    "notarization/apple_id_password",
    "keystore/release_password",
    "keystore/release_user",
    "ssh_remote_deploy/password",
)


def value(section: configparser.SectionProxy, key: str, default: str = "") -> str:
    return section.get(key, fallback=default).strip().strip('"')


def yes(section: configparser.SectionProxy, key: str) -> bool:
    return value(section, key).lower() == "true"


def finding(severity: str, code: str, message: str, preset: str = "") -> dict[str, str]:
    return {"severity": severity, "code": code, "preset": preset, "message": message}


def parse_presets(path: Path) -> configparser.RawConfigParser:
    parser = configparser.RawConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    with path.open("r", encoding="utf-8") as handle:
        parser.read_file(handle)
    return parser


def audit_file(path: Path, profile: str, preset_name: str | None = None) -> list[dict[str, str]]:
    if not path.is_file():
        return [finding("warning", "NO_PRESETS", "No export_presets.cfg exists; this is normal for the Nucleus template, but a consuming game's release needs export presets.")]

    try:
        parser = parse_presets(path)
    except (OSError, UnicodeError, configparser.Error) as exc:
        return [finding("error", "PARSE_FAILED", f"Could not parse export presets: {type(exc).__name__} (content not echoed).")]

    findings: list[dict[str, str]] = []
    indices = sorted(
        (int(m.group(1)) for key in parser.sections() if (m := re.fullmatch(r"preset\.(\d+)", key))),
    )
    if not indices:
        return [finding("error", "EMPTY_PRESETS", "No valid [preset.N] sections exist.")]

    matched = 0
    for index in indices:
        base = parser[f"preset.{index}"]
        name = value(base, "name", f"preset.{index}")
        if preset_name is not None and name != preset_name:
            continue
        matched += 1
        platform = value(base, "platform")
        opt_name = f"preset.{index}.options"
        opts = parser[opt_name] if parser.has_section(opt_name) else {}
        if not parser.has_section(opt_name):
            findings.append(finding("warning", "NO_PLATFORM_OPTIONS", "No platform options section found.", name))

        # Never disclose a sensitive value in findings, JSON, or CLI output.
        for section in (base, opts):
            for key in section:
                if key.lower() in SENSITIVE_OPTION_PATTERNS and value(section, key):
                    findings.append(finding("error", "POSSIBLE_SECRET_IN_PRESET", f"Potential sensitive setting in export_presets.cfg: {key}. Migrate it to Godot's credential storage and rotate the exposed value if necessary.", name))

        encrypted = yes(base, "encrypt_pck")
        filters = value(base, "encryption_include_filters")
        if encrypted:
            if not filters:
                findings.append(finding("error", "EMPTY_ENCRYPTION_FILTERS", "encrypt_pck is enabled but encryption_include_filters is empty; no protected resources may be selected.", name))
            custom = value(opts, "custom_template/release")
            if not custom:
                findings.append(finding("error", "NO_CUSTOM_RELEASE_TEMPLATE", "Encrypted PCK requires a compatible custom Godot release export template compiled with the same key.", name))
            findings.append(finding("info", "PCK_KEY_EXTERNAL", "Verify the matching encryption key is provided securely during template build/export; this audit intentionally does not read keys.", name))
        elif profile == "hardened" and platform.lower() in {"windows desktop", "linux", "macos", "mac osx"}:
            findings.append(finding("warning", "PCK_NOT_ENCRYPTED", "Hardened desktop profile expects encrypted PCK; decide whether its operational cost is justified for this game.", name))

        if platform.lower() == "windows desktop":
            if not yes(opts, "codesign/enable"):
                findings.append(finding("warning", "WINDOWS_SIGNING_OFF", "Code signing is not enabled in this preset; sign final release binaries and verify certificate identity.", name))
            if yes(opts, "binary_format/embed_pck") and yes(opts, "codesign/enable"):
                findings.append(finding("warning", "EMBED_AND_SIGN", "Review embedded PCK versus Windows signing compatibility for this engine/template; prefer detached PCK for the release pipeline.", name))

        if platform.lower() in {"macos", "mac osx"}:
            findings.append(finding("info", "MACOS_MANUAL_CHECK", "Manually verify production Developer ID signing, hardened runtime, notarization, and Gatekeeper behavior of the final app.", name))
        if platform.lower() in {"web", "android", "ios"}:
            findings.append(finding("info", "PLATFORM_LIMITS", "Review the platform-specific resource packaging model; desktop PCK assumptions do not automatically apply.", name))

        findings.append(finding("info", "RUNTIME_NOT_VERIFIED", "Configuration checked only: export, run, and inspect the final release artifact before claiming protection.", name))

    if preset_name is not None and matched == 0:
        findings.append(finding("error", "PRESET_NOT_FOUND", f"Export preset name not found: {preset_name!r}."))
    return findings


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--project", type=Path, default=Path("."), help="Consuming game's Godot project directory")
    ap.add_argument("--preset", help="Exact Godot export preset name; default: all")
    ap.add_argument("--profile", choices=("standard", "hardened"), default="standard")
    ap.add_argument("--strict", action="store_true", help="Exit non-zero on warnings and errors")
    ap.add_argument("--json", action="store_true", help="Output machine-readable findings without credentials")
    add_console_arguments(ap)
    args = ap.parse_args(argv)

    findings = audit_file(args.project / "export_presets.cfg", args.profile, args.preset)
    counts = {level: sum(f["severity"] == level for f in findings) for level in ("error", "warning", "info")}
    if args.json:
        # Preserve the exact machine-readable contract (no ANSI/no headers).
        print(json.dumps({"profile": args.profile, "counts": counts, "findings": findings}, ensure_ascii=False, indent=2))
    else:
        report = ConsoleReport("Game export security preflight", args)
        report.metric("Profile", args.profile + (" (strict)" if args.strict else ""))
        report.metric("Preset selection", args.preset or "All available presets")
        report.metric("Findings", f"{counts['error']} errors / {counts['warning']} warnings / {counts['info']} info")
        report.metric("Security scope", "Export configuration only; no keys, binaries, or runtime verified")
        blocking = [
            f"[{f['severity'].upper()}] [{f['code']}] {f['preset'] or 'project'}: {f['message']}"
            for f in findings if f["severity"] == "error" or (args.strict and f["severity"] == "warning")
        ]
        report.finish(blocking, warnings=0 if args.strict else counts["warning"])
        nonblocking = [f for f in findings if f["severity"] == "info" or (f["severity"] == "warning" and not args.strict)]
        if nonblocking and not args.quiet:
            print("\n  Additional findings:")
            for f in nonblocking:
                print(f"  [{f['severity'].upper()}] [{f['code']}] {f['preset'] or 'project'}: {f['message']}")
    return 1 if counts["error"] or (args.strict and counts["warning"]) else 0


if __name__ == "__main__":
    sys.exit(main())
