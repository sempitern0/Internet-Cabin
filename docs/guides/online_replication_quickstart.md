# Online Gameplay Replication Quickstart

## 1. Keep transport separate from gameplay replication

Use the existing optional:

```text
NucleusNetworkHandler
```

to establish an ENet/WebSocket peer when appropriate.

After the peer exists, Godot's high-level MultiplayerAPI owns network context.

Replication components should not create or destroy the transport themselves.

## 2. Use native MultiplayerSpawner

For replicated actor lifetime, configure a normal Godot
`MultiplayerSpawner`.

Example:

```text
Game
├── Players
└── MultiplayerSpawner
    spawn_path = ../Players
```

Register the player scene in the native spawner.

The authority/server should decide when that scene exists.

## 3. Use MultiplayerSynchronizer for discrete state

Inside a player scene:

```text
Player
├── MultiplayerSynchronizer
├── IntentChannel
└── TransformReplicator3D
```

Use `MultiplayerSynchronizer` for properties such as:

```text
health
selected weapon
animation state
team
is_dead
```

Do not also put the transform properties in that synchronizer when using the
Nucleus transform interpolator for the same Node.

## 4. Add the intent channel

Add:

```text
NucleusNetworkIntentChannel
```

and assign:

```text
controlling_peer_id = <player peer ID>
```

That ID must be configured authoritatively as part of player spawning/session
setup.

### Movement

For replaceable movement intent:

```gdscript
intent_channel.submit_unreliable(
	&"move",
	{
		&"direction": movement_input,
	},
)
```

### Discrete action

For an interaction request:

```gdscript
intent_channel.submit_reliable(
	&"interact",
	{
		&"target_id": target_id,
	},
)
```

The client is requesting an action, not declaring its result.

## 5. Validate on the server

Subclass the intent channel in the game:

```gdscript
class_name GamePlayerIntentChannel
extends NucleusNetworkIntentChannel


func validate_intent(
	peer_id: int,
	intent_id: StringName,
	payload: Dictionary,
	reliable: bool,
) -> Error:
	if peer_id != controlling_peer_id:
		return ERR_UNAVAILABLE

	match intent_id:
		&"move":
			if reliable:
				return ERR_INVALID_PARAMETER

			var direction: Variant = payload.get(
				&"direction"
			)

			if not direction is Vector2:
				return ERR_INVALID_PARAMETER

		&"interact":
			if not reliable:
				return ERR_INVALID_PARAMETER

		_:
			return ERR_DOES_NOT_EXIST

	return OK
```

Then connect:

```gdscript
intent_channel.intent_received.connect(
	_on_intent_received
)
```

and apply the request to **server-owned** gameplay systems.

Validation should still check the current authoritative state.

For interaction this might include:

```text
target still exists
distance is valid
line of sight is valid
actor is alive
action is allowed
cooldown/resource cost is valid
```

## 6. Replicate movement presentation

For a server-authoritative 3D actor:

```text
Player
└── TransformReplicator3D
```

Configure approximately:

```text
snapshot_interval = 0.05
interpolation_delay = 0.10
teleport_distance = 8.0
```

The authority sends at 20 Hz while remote peers interpolate approximately
100 ms behind the latest local arrival timeline.

Tune this with real latency/jitter measurements.

For 2D use `NucleusNetworkTransformReplicator2D`.

## 7. Authority ownership

The transform replicator uses Godot's own multiplayer authority.

For a server-authoritative actor, the default authority ID `1` is appropriate.

If your game changes multiplayer authority recursively, make sure the
replicator Node receives the intended authority too.

Do not accidentally make a cheating client's gameplay-critical transform
authoritative just to simplify presentation.

## 8. Teleports and respawns

When authoritative movement jumps farther than `teleport_distance`, remotes
clear interpolation history and snap to the new state.

For an explicit correction you can also call:

```gdscript
transform_replicator.clear_remote_buffer()
```

on the relevant remote lifecycle path when appropriate.

## 9. Persistent multiplayer objects

Keep identities separate:

```text
WorldEntity persistent UUID
≠
Multiplayer peer ID
≠
SceneTree instance ID
```

The server restores persistent state, decides which replicated objects should
exist, and lets `MultiplayerSpawner` materialize the network scene.

## 10. Inventory and loot

Clients should request:

```text
pick up item
move stack
equip item
open chest
```

The server validates and mutates `NucleusInventory` / `NucleusEquipment`.

Loot should be rolled on the authority and resolved results replicated.

Never accept a client payload that says:

```text
I received legendary_sword
```

as authoritative truth.

## 11. AI

Run authoritative Utility AI/navigation/gameplay decisions on the server for
network-relevant NPCs.

Clients normally need presentation state, not an independent authoritative AI
decision.

## 12. Production features deliberately left to the game

Implement only when the prototype proves the need:

```text
prediction/reconciliation
rewind hit validation
rollback
interest management
relay/matchmaking
anti-cheat
```

Nucleus intentionally stops before those choices because their correct design
depends heavily on the real game's movement, combat, player count, and latency
targets.
