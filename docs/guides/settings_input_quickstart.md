# Settings and Input Quickstart

Settings owns persisted preferences. Input owns device/source state, InputMap
bindings, labels/prompts, vibration and local-player device ownership.

## Settings flow

```text
SettingDefinition Resource
→ SettingsCatalog
→ NucleusSettings
→ setting_changed
→ focused applier / scene consumer
→ native Godot state
```

Do not mirror every `ProjectSettings` key into runtime settings. Add a setting
when it is genuinely a user preference with a clear runtime owner.

## Built-in graphics preferences

The default catalog includes reusable root-viewport settings for max FPS, render
scale, scaling mode, screen-space AA, TAA, MSAA and debanding. Environment-owned
features such as SSAO, SSIL, glow, volumetric fog, SDFGI and tonemapping remain
opt-in scene `Environment` policy.

## Built-in input comfort preferences

The default catalog also includes:

```text
input/mouse_look_sensitivity_scale
input/gamepad_look_sensitivity_scale
input/gamepad_move_deadzone
input/gamepad_look_deadzone
```

`NucleusLookRig3D` keeps its authored sensitivity as the baseline and multiplies
it by the persisted user scale. `NucleusMotionInput` uses the persisted gamepad
deadzone only when its scene export remains at the automatic `-1` value; an
explicit scene deadzone wins.

See [`../components/accessibility_preferences.md`](../components/accessibility_preferences.md).

## Semantic input first

Gameplay consumes actions, not physical keys:

```text
move_*
look_*
interact
primary_action
secondary_action
pause
project-specific semantic actions
```

Godot's `ui_*` actions remain navigation semantics for the currently active UI
layer. Do not interpret `ui_cancel` as a universal gameplay "leave" command.

## Single-player hot-swap

For a one-player session:

```gdscript
var local_player := local_input.join_keyboard_mouse(0)
motion_input.bind_local_player_input(local_player)
```

With:

```text
max_players = 1
single_player_hot_swap = true
```

meaningful keyboard/mouse, gamepad or touch activity moves the **same stable
`NucleusLocalPlayerInput` object** to the active source. Gameplay references stay
valid while UI prompts/glyphs can follow `NucleusInput.active_source`.

For couch multiplayer (`max_players > 1`), explicit seat/device ownership stays
authoritative; global hot-swap must not steal another player's device.

## Prompts and rebinding

Use `NucleusInputPromptBinding` or `NucleusInputGlyphBinding` rather than caching
strings such as `E`, `A`, `Cross` or `LMB`.

Use the Nucleus rebind capture/binding path so serialized bindings remain
source-aware. Gamepad bindings target compatible gamepads instead of persisting a
transient device ID.

`ui_*` rebinding is protected by default. If a game opts in, preserve a usable
accept/cancel fallback and test keyboard plus at least one gamepad family.

## Hold versus toggle

`NucleusInputActivationState` is a per-action semantic helper. Use it for options
such as "toggle aim" or "toggle crouch" without introducing one global toggle
policy for unrelated actions.

## Common mistakes

- hard-coding physical input in gameplay;
- using the globally active gamepad as multiplayer seat ownership;
- replacing the local-player object during single-player hot-swap;
- storing settings/input preferences in save-game payloads;
- making a scene-owned setting into another Autoload;
- duplicating prompt strings instead of deriving them from current bindings.

Hands-on: [`tutorials/bindings.md`](tutorials/bindings.md).
