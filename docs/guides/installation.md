# Installing Nucleus for a New Game

Nucleus is designed to be the **starting project** for a game. It is not an addon
that can be enabled from Project Settings, and it does not automatically merge
itself into another `project.godot`.

## Requirements

Use the engine line declared in [`../policies/godot_compatibility.md`](../policies/godot_compatibility.md).
The current CI-gated reference is Godot `4.7.2-stable`.

## Recommended: versioned release or pinned source

For a release package:

1. verify its SHA-256 checksum;
2. extract `Nucleus-<version>.zip`;
3. rename the project directory;
4. initialize the game's own repository;
5. open `project.godot` with the supported Godot version.

For a pinned checkout:

```bash
git clone https://github.com/sempitern0/Nucleus.git MyGame
cd MyGame
git checkout <exact-tag-or-commit>
rm -rf .git
git init
```

Record the source tag/commit in the game repository. Do not base a long-running
production project on an unrecorded moving `main`.

## First project setup

After opening the template:

1. change `application/config/name`;
2. replace the icon/presentation settings when appropriate;
3. create the game's main scene;
4. assign it as `run/main_scene`;
5. review the default InputMap actions;
6. keep the six baseline Autoloads until you intentionally redesign their documented responsibilities;
7. keep `default_bus_layout.tres` unless the game's audio architecture replaces it deliberately.

The absence of a default main scene is intentional.

## Validate the untouched baseline

Run:

```bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/productization_audit.py

godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
godot --headless --path . res://tests/smoke/smoke_main.tscn
```

In the editor you can also open `tests/headless/test_runner.tscn` and run the
current scene with **F6**. There is no separate editor-only test runner.

See [`validation_ci_quickstart.md`](validation_ci_quickstart.md) for the complete gate.

## Where game code should live

A practical starting layout is:

```text
game/
    actors/
    levels/
    systems/
    ui/
    data/
assets/
```

Keep `core/`, generic `components/` and optional `modules/` focused on reusable
infrastructure. Promote game behavior back into Nucleus only after repeated
cross-project evidence.

## Vendoring and upgrades

A consuming game owns its copied Nucleus source. Selective modification is
expected. Keep reusable changes focused, preserve tests for public behavior, and
merge later Nucleus versions intentionally rather than expecting package-manager
conflict resolution.

## Existing Godot projects

Integration into an established project is possible but is not a one-click path.
At minimum reconcile:

```text
Autoload names and ownership
InputMap actions
audio bus layout
project settings
settings/save paths
scene-flow assumptions
class_name collisions
existing architecture
```

Integrate only the Nucleus subsystems you actually need and follow their current
technical contracts.
