# Runtime Services Quickstart

The baseline ships four cross-scene runtime areas together because they are
application infrastructure, but they solve different problems.

Use this page as the map; follow the dedicated quickstart for actual setup.

## Audio

Use `NucleusAudio` for shared non-positional one-shots/music/bus policy.

Start with:

[`audio_quickstart.md`](audio_quickstart.md)

Hands-on:

[`tutorials/audio.md`](tutorials/audio.md)

## Save

Use `NucleusSave` for storage/format policy and `NucleusSaveSession` for explicit
scene-owned state participants.

Start with:

[`save_quickstart.md`](save_quickstart.md)

Hands-on:

[`tutorials/save_system.md`](tutorials/save_system.md)

Technical contract (including default save location and file layout):

[`../components/save_system.md`](../components/save_system.md)

## Scene flow

Use `NucleusSceneFlow` for observable scene replacement, background loading,
preflight instantiation, optional visual transitions, explicit failures, and
best-effort recovery.

Start with:

[`scene_flow_quickstart.md`](scene_flow_quickstart.md)

Hands-on:

[`tutorials/scene_flow.md`](tutorials/scene_flow.md)

## Localization

Godot `TranslationServer` remains authoritative. Nucleus adds locale resolution,
a persisted locale setting, selector metadata, and an `OptionButton` binding.

Start with:

[`localization_quickstart.md`](localization_quickstart.md)

Hands-on:

[`tutorials/localization.md`](tutorials/localization.md)

## Ownership reminder

These services are cross-scene by default; game-facing gameplay components remain
scene-owned.

Do not turn the service layer into a place for project-specific combat, world,
progression, or UI rules.

## Technical contract

[`../components/audio_save_scene_localization.md`](../components/audio_save_scene_localization.md)
