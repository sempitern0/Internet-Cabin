# Nucleus troubleshooting

Use this guide before adding a workaround around an existing Nucleus ownership
boundary. It focuses on problems that can look like framework failures while
actually coming from editor state, platform capability, or duplicated runtime
writes.

## A setting saves but does not change the game

1. Confirm the id exists in the active catalog.
2. Confirm the menu calls `NucleusSettings.set_value()` successfully.
3. Identify the applier/consumer that owns the runtime side effect.
4. Test the native runtime property, not only the saved config file.
5. Check whether the feature is available on the current platform/renderer.

Writing a `ProjectSettings` key during play often does not reconfigure already
running engine state. Use the matching runtime API through the owner documented
by Nucleus.

## Fullscreen appears broken in the editor

Godot game embedding cannot validate ordinary desktop window transitions. Disable
**Embed Game on Next Play** or run an exported/separate window before changing
fullscreen code.

Web and native-mobile targets intentionally use managed window behavior.

## Graphics option has no visible effect

Check whether the option belongs to the root `Viewport` or to an `Environment`.
They have different owners. Then check the selected renderer and actual scene:
for example, an Environment toggle cannot affect a scene that uses another
Environment resource.

Do not assume that every catalog option is meaningful on every renderer. Hide
unsupported choices in game UI.

## Input works in menus but conflicts with gameplay

Remember the three layers:

```text
physical event → InputMap action → active consumer
```

`ui_*` actions are UI navigation. Gameplay should consume semantic gameplay
actions. The same physical key/button may map to both when context keeps them
unambiguous.

## Rebinding changed the wrong controller behavior

Use the Nucleus binding codec/session APIs rather than storing transient device
ids in game data. UI-navigation actions are protected from rebinding by default
so accept/cancel cannot accidentally become unusable.

## Touch and gamepad hot-swap behaves unexpectedly

Verify that the project is using one stable `NucleusLocalPlayerInput` seat and
that touch controls feed ordinary InputMap actions. Editor touch emulation is not
identical to physical touchscreen input; reproduce source-detection issues on a
real device before creating a parallel mobile input API.

## Unicode/NUL or UID errors appear after a large update

If a clean repository/CI import succeeds, close Godot and regenerate the local
`.godot/` cache before modifying source files. `Unexpected NUL character` can
also indicate a genuinely mis-encoded text file, so scan tracked text for NUL
bytes if the error survives a clean cache/import.

Do not delete versioned `.gd.uid` files as a generic cache-cleaning step.

## A headless test exists but CI does not run it

Every `tests/headless/*_test.gd` suite must be listed in
`tests/headless/test_manifest.gd`. Static checks intentionally fail when the
filesystem and manifest disagree.

## Content pack fails to load

Keep integrity, entitlement, and trust separate:

- official PCKs must pass manifest/hash/signature verification before mount;
- PATCH packs are bootstrap-time content;
- community content is data-only by default and is not mounted as a PCK.

Do not bypass `NucleusContentPackLoader` to make an unverified pack load.

## Mobile feature is unavailable

Query Nucleus platform/capability helpers and preserve a no-op/fallback path.
Permissions, orientation, sensors, and handheld haptics vary by platform and
export configuration.

## CI passes static checks but Godot still fails

Static checks do not replace engine parsing. Reproduce with the pinned Godot
version, then classify the problem as parser/import, initialization/runtime, or a
legitimate platform warning. The CI import/parser/headless/smoke stages are the
authoritative repository gate.
