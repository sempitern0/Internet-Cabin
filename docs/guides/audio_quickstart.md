# Audio Quickstart

Use Nucleus audio for shared non-positional playback and settings-driven bus
policy while keeping Godot's AudioServer/bus layout authoritative.

For a build-along example, see:

[`tutorials/audio.md`](tutorials/audio.md)

## 1. Use the existing Autoload

`NucleusAudio` is already part of the default baseline.

Do not create a second global audio manager in each game scene.

## 2. Play a transient sound

```gdscript
@export var confirm_sound: AudioStream


func play_confirm() -> void:
    NucleusAudio.play_one_shot(
        confirm_sound,
        NucleusAudioBuses.UI,
    )
```

The one-shot pool owns the temporary `AudioStreamPlayer` lifecycle.

## 3. Prefer reusable AudioCue resources

Create a `NucleusAudioCue` Resource when the same sound policy is reused.

Configure:

```text
stream
bus
volume_linear
pitch_scale
from_position
```

Then:

```gdscript
NucleusAudio.play_cue(confirm_cue)
```

Use `AudioStreamRandomizer` as the cue's stream when Godot's built-in weighted
sample/pitch/volume randomization is appropriate.

## 4. Keep positional audio native

For a sound that belongs to a world object, normal Godot ownership is usually
clearer:

```text
AudioStreamPlayer2D
AudioStreamPlayer3D
```

Nucleus's global one-shot path is for non-positional shared playback.

## 5. Built-in buses

Use `NucleusAudioBuses` identifiers for the default layout rather than repeating
string literals across the game.

The baseline includes categories such as:

```text
MASTER
MUSIC
SFX
UI
VOICE
AMBIENT
```

Godot's bus layout remains the actual mixer.

## 6. Settings already drive bus volume

The default settings service applies built-in audio preferences to the matching
buses.

An options Slider should bind to the setting instead of calling `AudioServer`
directly.

See:

[`tutorials/bindings.md`](tutorials/bindings.md)

## 7. Choose scene ownership for long-lived audio

Use global `NucleusAudio` for application-wide music/shared one-shots.

Use scene-owned players when the sound lifetime naturally belongs to:

```text
an enemy
a machine
a boat engine
a waterfall
a world ambience emitter
```

## Common mistakes

- constructing a new `AudioStreamPlayer` for every UI click;
- putting positional 3D audio into a global non-positional player;
- bypassing Nucleus audio settings from the options UI;
- hard-coding bus strings everywhere;
- confusing content selection with mixer policy.

## Related documentation

- [`tutorials/audio.md`](tutorials/audio.md)
- [`runtime_services_quickstart.md`](runtime_services_quickstart.md)
- [`tutorials/bindings.md`](tutorials/bindings.md)
- [`../components/audio_save_scene_localization.md`](../components/audio_save_scene_localization.md)
