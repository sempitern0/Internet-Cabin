# Tutorial: use the Nucleus core services

This tutorial builds a tiny game shell that changes scene, reads/writes a
setting, plays audio, saves plain data, loads it again, and reacts to input
without recreating application-wide services in every scene.

## What you will use

Nucleus configures these Autoloads by default:

```text
NucleusApp
NucleusSettings
NucleusInput
NucleusAudio
NucleusSave
NucleusSceneFlow
```

The exact contracts are documented in:

- [`../../components/core_runtime.md`](../../components/core_runtime.md)
- [`../../components/settings_and_input.md`](../../components/settings_and_input.md)
- [`audio_save_scene_localization.md`](../../components/audio_save_scene_localization.md)

## 1. Create a game-owned main scene

Create:

```text
GameMain : Control
└── VBoxContainer
    ├── StartButton
    ├── SaveButton
    └── LoadButton
```

Save it somewhere owned by the game, for example:

```text
res://game/main.tscn
```

Assign it as the project's main scene.

Nucleus deliberately does not choose this scene for a consuming game.

## 2. Change to a gameplay scene with SceneFlow

Create another scene:

```text
World : Node2D
```

Save it as:

```text
res://game/world.tscn
```

Connect `StartButton.pressed` and request the transition:

```gdscript
const WORLD_SCENE := "res://game/world.tscn"


func _on_start_pressed() -> void:
    if NucleusSceneFlow.is_busy():
        return

    var error: Error = NucleusSceneFlow.change_scene(WORLD_SCENE)

    if error != OK:
        push_error("Could not open world: %s" % error_string(error))
```

`NucleusSceneFlow` owns loading/transition coordination. It does not own your
loading-screen visuals.

A loading UI can observe:

```text
transition_started
load_progress
transition_completed
transition_failed
busy_changed
```

Use native `SceneTree` changes for trivial isolated transitions if shared
transition policy is unnecessary.

## 3. Read and change a setting

For an existing setting:

```gdscript
var master_volume: float = NucleusSettings.get_float(
    &"audio/master_volume",
    0.9,
)

NucleusSettings.set_value(
    &"audio/master_volume",
    0.75,
)
```

The important rule is:

```text
UI/game code
→ NucleusSettings
→ setting_changed
→ matching applier
→ Godot runtime API
```

Do not make an options menu call `AudioServer`,
`DisplayServer.window_set_mode()`, or similar runtime APIs directly when a
Nucleus applier already owns that setting.

For UI, prefer the binding tutorial instead of writing this synchronization by
hand:

[`bindings.md`](bindings.md)

## 4. Observe a setting when game code needs it

A game-specific system may react to its own setting:

```gdscript
func _ready() -> void:
    NucleusSettings.setting_changed.connect(_on_setting_changed)


func _on_setting_changed(
    setting_id: StringName,
    value: Variant,
    _previous_value: Variant,
) -> void:
    if setting_id == &"gameplay/camera_sensitivity":
        camera_sensitivity = float(value)
```

If many scenes need the same runtime application rule, prefer one game-owned
applier instead of repeating the connection everywhere.

## 5. Play a one-shot sound

Given an `AudioStream` resource:

```gdscript
@export var confirm_sound: AudioStream


func _play_confirm() -> void:
    NucleusAudio.play_one_shot(
        confirm_sound,
        NucleusAudioBuses.UI,
    )
```

For a reusable sound policy, create a `NucleusAudioCue` Resource and use:

```gdscript
NucleusAudio.play_cue(confirm_cue)
```

This reuses the Core one-shot pool instead of creating and destroying an
`AudioStreamPlayer` for every transient UI/game sound.

Positional world audio can still use native `AudioStreamPlayer2D/3D` where that
is the simpler ownership model.

## 6. Save plain game data

For the smallest possible manual save:

```gdscript
var payload: Dictionary = {
    "player": {
        "coins": 12,
        "checkpoint": "beach",
    },
}

var result: NucleusSaveResult = NucleusSave.save_manual(
    "slot_1",
    payload,
    {
        "display_name": "My first save",
    },
)

if not result.succeeded():
    push_error("Save failed: %s" % error_string(result.error))
```

Keep payloads data-oriented:

```text
String / StringName-compatible values
numbers
bool
arrays
dictionaries
other save-validator-supported plain data
```

Do not store live Nodes, scene references, or transient object pointers.

For larger games, prefer a `NucleusSaveSession` and register scene/system
participants so capture/restore stays owned by the systems that understand the
data.

## 7. Load the save

```gdscript
var result: NucleusSaveResult = NucleusSave.load_manual("slot_1")

if not result.succeeded():
    push_error("Load failed: %s" % error_string(result.error))
    return

var payload: Dictionary = result.document.payload
var player_data: Dictionary = payload.get("player", {})

print(player_data.get("coins", 0))
```

Storage, encoding, migration, and save-file policy belong to `NucleusSave`.
Applying the loaded values back to a Player/World belongs to the game or to a
registered `NucleusSaveSession` participant.

## 8. Use semantic input

Do not ask whether a physical key is pressed:

```gdscript
if Input.is_key_pressed(KEY_E):
    pass
```

Ask for the semantic action:

```gdscript
if Input.is_action_just_pressed(NucleusInputActions.INTERACT):
    interact()
```

For movement/camera composition use `NucleusMotionInput`.

For local multiplayer or a single-player session that can hot-swap between
keyboard/mouse and gamepad, use `NucleusLocalInputSession` and bind a stable
`NucleusLocalPlayerInput`.

See:

[`bindings.md`](bindings.md)

## 9. Localize display text

Put stable keys in your `.po`/translation resources and present them through
Godot localization:

```gdscript
%Title.text = tr("MAIN_MENU_TITLE")
```

Do not save the translated output as durable game state.

If the locale is exposed as a Nucleus setting, change the setting and let its
applier update `TranslationServer`.

## 10. Validation checklist

Before adding gameplay systems, verify:

- the project boots into the game-owned main scene;
- `NucleusSceneFlow` changes to the world scene;
- a setting change persists and applies at runtime;
- a one-shot plays through the expected audio bus;
- a manual save succeeds;
- the same slot loads and returns the expected payload;
- gameplay queries semantic InputMap actions rather than physical devices.

## Where to go next

- UI/settings/input synchronization:
  [`bindings.md`](bindings.md)
- executable gameplay abilities:
  [`gameplay_actions.md`](gameplay_actions.md)
- common scene components:
  [`components_first_steps.md`](components_first_steps.md)
