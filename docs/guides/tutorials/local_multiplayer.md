# Tutorial: build local input seats for keyboard and gamepads

This tutorial shows both one-player hot-swap and a simple couch-multiplayer join
flow.

## Part A: one-player keyboard/gamepad hot-swap

### 1. Scene

```text
Session : Node
├── LocalInput : NucleusLocalInputSession
└── Player : CharacterBody3D
    └── MotionInput : NucleusMotionInput
```

Configure:

```text
LocalInput.max_players = 1
LocalInput.reserve_keyboard_mouse_player = false
LocalInput.auto_join_gamepads = false
LocalInput.single_player_hot_swap = true
```

### 2. Create one stable seat

```gdscript
@onready var local_input: NucleusLocalInputSession = %LocalInput
@onready var motion_input: NucleusMotionInput = %Player/MotionInput


func _ready() -> void:
    var player_input: NucleusLocalPlayerInput = (
        local_input.join_keyboard_mouse(0)
    )

    motion_input.bind_local_player_input(player_input)
```

Now the same `NucleusLocalPlayerInput` object can change owned device when
meaningful keyboard/gamepad activity changes source.

The motor/camera keeps its reference.

### 3. Verify

Move with WASD, then touch the left stick, then use WASD again.

The gameplay actor should continue without respawning or rebinding the
`NucleusMotionInput` manually.

## Part B: two-player couch multiplayer

### 4. Configure explicit seats

Use:

```text
max_players = 4
reserve_keyboard_mouse_player = false
auto_join_gamepads = true
```

For multiple players, do not rely on single-player hot-swap as the ownership
policy.

### 5. Spawn/bind one actor per joined player

Connect before manually creating the keyboard seat:

```gdscript
func _ready() -> void:
    local_input.player_joined.connect(_on_player_joined)
    local_input.player_left.connect(_on_player_left)

    local_input.join_keyboard_mouse(0)
```

Then:

```gdscript
func _on_player_joined(input: NucleusLocalPlayerInput) -> void:
    var player := PLAYER_SCENE.instantiate()
    add_child(player)

    player.name = "Player%d" % input.player_index
    player.get_node("MotionInput").bind_local_player_input(input)
```

A connected gamepad can auto-join an available seat when it produces a button
press.

### 6. Explicit "Press A to Join"

Set:

```text
auto_join_gamepads = false
```

and react to:

```gdscript
func _ready() -> void:
    local_input.join_requested.connect(_on_join_requested)


func _on_join_requested(device_id: int) -> void:
    local_input.join_gamepad(device_id)
```

A real join screen can first show the device and let the game choose a player
slot/team/profile before calling `join_gamepad()`.

## Part C: device disconnect/reconnect

Observe:

```gdscript
local_input.player_device_disconnected.connect(_on_disconnected)
local_input.player_device_reconnected.connect(_on_reconnected)
local_input.player_device_changed.connect(_on_device_changed)
```

The game decides presentation policy:

```text
toast only
pause local session
show reconnect modal
allow remaining players to continue
```

Do not put those product decisions inside Core input routing.

## Important distinction: local seat versus online peer

A local `player_index` is not a multiplayer network peer ID.

A future online couch-co-op game may have multiple local seats under one online
client peer. Keep those identities separate from the beginning.

## Common mistakes

- reading global `Input.get_vector()` inside a per-seat player after binding local
  input;
- using `NucleusInput.active_gamepad_id` as the owner of every player;
- creating per-player InputMaps;
- respawning a player because the controller changed;
- treating local player index as online authority identity.

## Related docs

- [`../local_multiplayer_quickstart.md`](../local_multiplayer_quickstart.md)
- [`../settings_input_quickstart.md`](../settings_input_quickstart.md)
- [`bindings.md`](bindings.md)
- [`../../components/settings_and_input.md`](../../components/settings_and_input.md)
