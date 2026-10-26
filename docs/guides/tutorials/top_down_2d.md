# Tutorial: assemble a top-down 2D actor using common Nucleus components

Use the same `NucleusCharacterMotor2D` as a floor-based character. This time,
select the native Godot motion mode for unrestricted XY movement.

## Player scene

```text
Player : CharacterBody2D
├── CollisionShape2D
├── AnimatedSprite2D
├── MotionInput : NucleusMotionInput
└── Motor : NucleusCharacterMotor2D
```

Set `Player.motion_mode = MOTION_MODE_FLOATING`. Configure the same motor as in
the platformer tutorial, with player semantic input as its intent source.
Choose movement speed and acceleration to suit your game's scale.

No platformer flags, sprite-facing policy, or alternate top-down motor are needed.
Native `CharacterBody2D.move_and_slide()` still handles collision response.

## NPC navigation using the same motor

```text
NPC : CharacterBody2D
├── CollisionShape2D
├── NavigationAgent2D
├── Follower : NucleusNavigationFollower2D
├── NavigationSource : NucleusNavigationMotionSource2D
└── Motor : NucleusCharacterMotor2D
```

Set `NPC.motion_mode = MOTION_MODE_FLOATING`. Assign:

```text
Follower.agent = NavigationAgent2D
Follower.origin = NPC
NavigationSource.follower = Follower
Motor.body = NPC
Motor.motion_source = NavigationSource
```

Schedule Follower physics processing before Motor physics processing. Feed
AI decisions to the follower using `follow_node(target)` or
`set_target_position(position)`. The navigation component produces intent; the
motor remains the only writer of physical velocity and motion.

## Facing, animation and combat

The game decides whether the sprite follows movement, aim, a locked-on target,
or authored directional clips. Example simple orientation:

```gdscript
if absf(player.velocity.x) > 0.01:
	animated_sprite.flip_h = player.velocity.x < 0.0
```

For a full animation graph, use `NucleusAnimationVelocityBinding2D` and Godot
`AnimationTree`. `NucleusHitbox2D`, `NucleusHurtbox2D`,
`NucleusDamageReceiver`, `NucleusValuePool`, targeting and gameplay actions are
already neutral, composable and reusable. The game creates enemy types,
damage rules, combos and art.

## Validation checklist

- Same motor script works for the input-driven player and navigation-driven NPC.
- Enabling/disabling a motion source does not double-write `CharacterBody2D`.
- Native collisions and avoidance do not leak into the animation layer.
- Pausing or despawning an actor cleans up scene-owned relationships.

See [`2d_foundation.md`](2d_foundation.md) for the common contract.
