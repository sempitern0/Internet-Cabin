# Tutorial — Creating Custom Development Commands

This tutorial builds a game-owned command for Nucleus Development Tools and
explains the conventions that keep custom commands discoverable, safe, and easy
to remove from production builds.

The important rule is simple:

```text
Development Tools owns discovery and invocation.
The gameplay/system owner still owns the operation.
```

Do not put game rules into the registry itself.

## Goal

Assume a game has authored teleport markers and a boat controller. We want this
command:

```text
boat.teleport harbor_start true
```

Arguments:

```text
marker
    required String

zero_velocity
    optional bool, defaults to true
```

The command should find an authored marker, ask the boat owner to perform the
teleport, and return a useful result to the palette.

## 1. Create a scene-owned command adapter

Create a script beside the system that owns the behavior, for example:

```text
game/development/boat_development_commands.gd
```

```gdscript
class_name BoatDevelopmentCommands
extends Node

@export var registry: NucleusDevelopmentCommandRegistry
@export var boat: BoatController
@export var marker_root: Node3D

var _registered_ids: Array[StringName] = []
```

Scene-owned references make dependencies explicit. Avoid looking up arbitrary
singletons or searching the entire tree from the command callback when the scene
can wire the owner directly.

## 2. Register the command

```gdscript
func _ready() -> void:
    if registry == null or boat == null or marker_root == null:
        push_warning("BoatDevelopmentCommands is not fully configured.")
        return

    _register(
        NucleusDevelopmentCommand.build(
            &"boat.teleport",
            "Teleport boat to marker",
            Callable(self, "_teleport_boat"),
            "Moves the active boat to an authored development marker.",
            &"Boat",
            [
                NucleusDevelopmentCommandArgument.build(
                    &"marker",
                    TYPE_STRING,
                    "Child marker name under marker_root.",
                ),
                NucleusDevelopmentCommandArgument.build(
                    &"zero_velocity",
                    TYPE_BOOL,
                    "Clear velocity after teleport.",
                    true,
                    true,
                ),
            ],
            PackedStringArray(["boat.tp"]),
            PackedStringArray(["boat", "teleport", "fixture"]),
        )
    )
```

A good command definition gives the palette enough metadata to be useful:

```text
stable ID
human title
description
category
typed arguments
optional aliases
search tags
```

### Naming convention

Prefer namespaced IDs:

```text
boat.teleport
encounter.spawn
quest.set_state
weather.force
inventory.grant
```

Avoid vague global names such as:

```text
spawn
set
run
fix
```

The namespace makes search results predictable as the project grows.

## 3. Keep registration lifetime explicit

Use one helper and unregister when the adapter leaves scope:

```gdscript
func _register(command: NucleusDevelopmentCommand) -> void:
    if registry.register_command(command) == OK:
        _registered_ids.append(command.id)


func _exit_tree() -> void:
    if registry == null:
        return
    for id: StringName in _registered_ids:
        registry.unregister_command(id)
```

This is particularly useful for level-specific commands. Entering a harbor scene
can register harbor fixtures; leaving it removes them automatically.

A persistent command may instead live in the same persistent development shell
as its owner.

## 4. Implement the callback through the real owner

```gdscript
func _teleport_boat(
    arguments: Array,
    _context: Dictionary,
) -> NucleusDevelopmentCommandResult:
    var marker_name := str(arguments[0])
    var zero_velocity := bool(arguments[1])
    var marker := marker_root.get_node_or_null(NodePath(marker_name)) as Node3D

    if marker == null:
        return NucleusDevelopmentCommandResult.failure(
            "Unknown boat marker: %s" % marker_name
        )

    boat.teleport_to(marker.global_transform, zero_velocity)
    return NucleusDevelopmentCommandResult.success(
        "Boat teleported to %s." % marker_name
    )
```

The important part is this line:

```gdscript
boat.teleport_to(...)
```

The command calls the gameplay API that already owns teleport semantics. It does
not manually set six unrelated properties and hope that the result is equivalent.

This preserves invariants such as:

```text
physics state
velocity reset
network authority
camera synchronization
navigation state
signals / analytics hooks
```

when the owner chooses to handle them.

## 5. Use typed arguments

The command argument layer supports:

```text
TYPE_STRING
TYPE_INT
TYPE_FLOAT
TYPE_BOOL
```

A required argument:

```gdscript
NucleusDevelopmentCommandArgument.build(
    &"count",
    TYPE_INT,
)
```

An optional argument with a default:

```gdscript
NucleusDevelopmentCommandArgument.build(
    &"aggressive",
    TYPE_BOOL,
    "Spawn in aggressive state.",
    true,
    false,
)
```

A string choice behaves like a small enum:

```gdscript
NucleusDevelopmentCommandArgument.build(
    &"weather",
    TYPE_STRING,
    "Weather fixture.",
    false,
    null,
    PackedStringArray(["clear", "rain", "storm"]),
)
```

Then the command is self-documenting:

```text
weather.force <weather=clear|rain|storm>
```

Required arguments must precede optional arguments.

## 6. Return normalized results

Use:

```text
NucleusDevelopmentCommandResult.success()
NucleusDevelopmentCommandResult.warning()
NucleusDevelopmentCommandResult.failure()
```

Examples:

```gdscript
return NucleusDevelopmentCommandResult.success("Spawned 5 enemies.")
```

```gdscript
return NucleusDevelopmentCommandResult.warning(
    "Fixture loaded, but no navigation map is active."
)
```

```gdscript
return NucleusDevelopmentCommandResult.failure(
    "No active player inventory was found."
)
```

The registry records the status and message in bounded command history, so clear
messages make later debugging much easier.

A callback may return a String as a successful shorthand, but explicit results
are preferable once a command has meaningful failure conditions.

## 7. Use invocation context when it is genuinely useful

Callbacks receive a context dictionary. The registry adds:

```text
registry
command_id
```

The palette also supplies its source object.

Do not turn context into a hidden dependency bag. Prefer exported references to
real owners. Context is most useful for invocation metadata or adapters that need
to distinguish where a command came from.

## 8. Test command behavior separately from the palette

The palette is presentation. The valuable test is normally the owner or adapter
contract.

A small command-registry test can verify registration and execution:

```gdscript
var registry := NucleusDevelopmentCommandRegistry.new()
var command := NucleusDevelopmentCommand.build(
    &"test.echo",
    "Echo",
    func(arguments: Array, _context: Dictionary) -> String:
        return str(arguments[0]),
    "",
    &"Test",
    [NucleusDevelopmentCommandArgument.build(&"value", TYPE_STRING)],
)

expect_equal(registry.register_command(command), OK, "Command registers.")
var result := registry.execute_line('test.echo "hello world"')
expect_true(result.is_success(), "Command executes.")
expect_equal(result.message, "hello world", "Quoted argument is preserved.")
```

For a gameplay command, test the underlying gameplay owner independently where
possible, then add a thin adapter test for argument/result behavior.

## 9. Decide between `node.set` and a custom command

Use Scene Object Console when you are exploring:

```text
node.inspect Boat speed
node.set Boat max_speed 24
node.position3d Boat 10 0 -5
```

Create a custom command when the action becomes repeatable or semantic:

```text
boat.fixture race_start
boat.damage_engine 0.5
encounter.spawn pirate_ambush
```

A useful heuristic:

```text
one temporary property experiment
    -> generic node command

same multi-step action for the third time
    -> custom domain command
```

That progression keeps the command palette productive without accumulating a
second gameplay API made of debug-only property mutations.

## 10. Security and release boundary

Do not add commands that accept text and then perform:

```text
eval / Expression execution
Object.call() with a user-provided method name
OS.execute()
arbitrary Resource loading followed by code execution
arbitrary property paths across global objects
```

Commands are an explicit allowlist of development actions.

The Development Tools shell remains debug-only by default. If a project builds a
special QA configuration that includes it, treat that as explicit product
policy rather than silently shipping the console in production.

## Complete workflow

A mature development loop can now look like:

```text
scene.nodes boat
node.inspect World/Boat speed
node.set World/Boat max_speed 22
boat.fixture storm_run
validation.run
performance.trace storm_run_start
...play scenario...
performance.report
```

The generic scene console handles exploration. Custom commands capture repeated
domain operations. Validation checks contracts. Performance tools measure the
result. Each concern stays behind its own owner while sharing one searchable
command surface.
