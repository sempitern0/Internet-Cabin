# Local Multiplayer and Input Seats Quickstart

Use `NucleusLocalInputSession` when gameplay needs explicit local-player device
ownership.

This covers both couch multiplayer and a one-player session that seamlessly
hot-swaps between keyboard/mouse and gamepad.

For the build-along version, see:

[`tutorials/local_multiplayer.md`](tutorials/local_multiplayer.md)

## Single-player hot-swap

A one-player session can keep one stable `NucleusLocalPlayerInput` object while
the owned device changes.

Typical configuration:

```text
max_players = 1
single_player_hot_swap = true
```

Bind that stable seat once:

```gdscript
var player_input := local_input.join_keyboard_mouse(0)
motion_input.bind_local_player_input(player_input)
```

Gamepad activity can move the same seat to the active controller; keyboard/mouse
activity can move it back.

Gameplay systems do not need to be recreated.

## Couch multiplayer

For multiple players:

```text
max_players > 1
single_player_hot_swap no longer owns the session policy
```

Each `NucleusLocalPlayerInput` represents one local seat/device context.

Use:

```text
join_keyboard_mouse
join_gamepad
leave_player
get_player
get_players
get_player_for_gamepad
```

## Auto-join versus join screen

For drop-in joining:

```text
auto_join_gamepads = true
```

For an explicit "Press A to Join" screen:

```text
auto_join_gamepads = false
```

Then react to:

```text
join_requested(device_id)
```

and decide which player slot to assign.

## Bind gameplay components per seat

Each spawned local player normally owns its own `NucleusMotionInput`.

```gdscript
motion_input.bind_local_player_input(local_player_input)
```

The motor/camera/action adapters can then read the correct per-player input
stream without forking Godot's InputMap.

## Device connection lifecycle

Useful signals include:

```text
player_joined
player_left
player_input
player_device_disconnected
player_device_reconnected
player_device_changed
join_requested
```

Do not route every local player through `NucleusInput.active_gamepad_id`; that is
global presentation state, not multiplayer seat ownership.

## Common mistakes

- creating a separate InputMap for every player;
- replacing the player object when only its device changes;
- reading global `Input` polling from gameplay that should be seat-specific;
- using active gamepad state as couch-multiplayer ownership;
- mixing local seat assignment with online peer authority.

## Related documentation

- [`tutorials/local_multiplayer.md`](tutorials/local_multiplayer.md)
- [`settings_input_quickstart.md`](settings_input_quickstart.md)
- [`tutorials/bindings.md`](tutorials/bindings.md)
- [`../components/settings_and_input.md`](../components/settings_and_input.md)
