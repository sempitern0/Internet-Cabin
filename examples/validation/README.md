# Validation scenes

These scenes are intentionally small, removable composition fixtures.

- `gameplay_2d.tscn` wires `ValuePool`, `Regenerator`, `TargetingAgent`, and a
  native `Area2D` targeting sensor.
- `gameplay_3d.tscn` mirrors the same composition with Godot's 3D nodes.

They are not demo games and do not introduce sample art, bespoke controllers,
or project-specific mechanics. Their purpose is to make editor wiring visible
and to provide compact scenes that can be opened manually after changes to the
corresponding systems.

The automated bootstrap fixture lives in `tests/smoke/smoke_main.tscn`.
