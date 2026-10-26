# Development Tools — Scene Object Console

## Status

The Scene Object Console extends the optional Development Tools module with
current-scene discovery, Inspector-like property inspection, and bounded runtime
mutation.

It is development tooling. It is not a production remote console, a generic
reflection API, or a replacement for the Godot Remote scene tree/Inspector.

The ready shell registers the commands automatically through:

```text
NucleusSceneObjectDevelopmentCommands
```

The reusable backend is:

```text
NucleusSceneObjectTools
```

The backend does not depend on palette presentation, so tests or another local
development UI may reuse it directly.

## Why this exists

During gameplay iteration a developer repeatedly needs to answer questions like:

```text
what is the runtime path of this node?
what type is it?
which nodes belong to this group?
what is the current value of this exported parameter?
what happens if I move this object ten metres?
what happens if I hide or stop processing this object?
```

Godot's Remote scene tree and Inspector remain the deepest visual tools. The
command surface exists for the faster loop where the game is already focused and
a developer wants one reproducible action without switching tools.

## Commands

### Discover nodes

```text
scene.nodes [query] [limit]
scene.group <group> [limit]
```

Examples:

```text
scene.nodes
scene.nodes boat
scene.nodes CharacterBody3D 25
scene.group enemies
```

`scene.nodes` searches the scene-relative path, node name, and native class.
Results are bounded to 200 entries.

Paths emitted by these commands are designed to be copied into the other scene
object commands.

## Inspect a node

```text
node.inspect <path> [query]
```

Examples:

```text
node.inspect Player
node.inspect World/Boat
node.inspect World/Boat speed
node.inspect Debug/Marker color
```

Inspection only shows editor-visible property types supported by the console:

```text
bool
int / enum
float
String
StringName
Vector2 / Vector2i
Vector3 / Vector3i
Color
```

Read-only properties may be displayed, but cannot be changed through
`node.set`.

## Change an Inspector-like property

```text
node.set <path> <property> <value>
```

Examples:

```text
node.set Boat max_speed 18.5
node.set Boat debug_enabled true
node.set Boat team_name "Harbor Patrol"
node.set Boat spawn_offset "10,2,-4"
node.set Boat modulate "#ffcc88"
node.set Boat process_mode disabled
```

For vector values, use comma-separated components. Quotes are useful when the
value contains spaces.

Integer enum properties accept either their numeric value or an option label
from the Inspector hint when Godot exposes one.

### Mutation boundary

`node.set` intentionally does not support:

```text
Object / Resource references
NodePath references
Array / Dictionary values
Callable / Signal values
RID values
Transform2D / Transform3D / Basis / Quaternion
arbitrary method calls
```

Structural properties are also blocked:

```text
name
owner
script
scene_file_path
```

This keeps the command useful for runtime tuning without turning text input into
a general object graph editor or code-execution mechanism.

## Transform shortcuts

Dedicated transform commands are clearer and safer than encoding transforms in
`node.set`:

```text
node.position2d <path> <x> <y> [local|global]
node.position3d <path> <x> <y> <z> [local|global]
node.rotation2d <path> <degrees>
node.rotation3d <path> <x_deg> <y_deg> <z_deg>
node.scale2d <path> <x> <y>
node.scale3d <path> <x> <y> <z>
```

Examples:

```text
node.position3d Boat 120 2 -35 global
node.rotation3d Boat 0 90 0
node.scale3d Debug/SpawnMarker 2 2 2
node.position2d UI/DebugMarker 640 360
```

Rotation values are degrees because that is usually the most convenient unit
for interactive development commands.

## Runtime switches

```text
node.visible <path> <bool>
node.process <path> <bool>
```

`node.visible` supports `CanvasItem` and `Node3D` descendants.

`node.process` toggles both idle and physics processing. It does not recursively
change descendants and does not alter a node's process mode enum. This makes it
a quick local freeze/unfreeze tool rather than a scene-wide pause system.

## Current-scene boundary

All paths are resolved below `SceneTree.current_scene`.

```text
.
Player
World/Boat
Debug/SpawnMarker
```

Absolute paths are rejected. The console does not use `/root` paths to reach
Autoloads or unrelated persistent nodes. Systems with global ownership should
expose their own explicit development commands instead.

This boundary is important: Scene Object Console is a convenience surface for
scene iteration, not a Service Locator.

## Relationship to validation

Validation and Scene Object Console solve different phases of the loop:

```text
scene.nodes / node.inspect
    discover runtime state

node.set / node.position3d / node.visible
    perturb the running scenario

validation.run
    check authored/runtime configuration contracts

performance.*
    measure the resulting workload
```

Together they support fast, reproducible development experiments without
merging those concerns into one monolithic debug manager.

## When to write a custom command instead

Use `node.set` for short-lived tuning of simple editor-visible data.

Write a custom command when an action has domain semantics or must preserve
invariants, for example:

```text
boat.teleport_to_dock
encounter.spawn
inventory.grant
quest.advance
weather.force
network.connect_test_peer
```

A custom command should call the subsystem that owns the behavior rather than
changing several raw node properties to imitate that subsystem.

See `docs/guides/custom_development_commands_tutorial.md`.
