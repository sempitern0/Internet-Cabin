# Tutorial: assemble a 2D platformer using common Nucleus components

A platformer is a *game configuration*, not a Nucleus subclass. Build it using
`NucleusCharacterMotor2D`, Godot `CharacterBody2D`, semantic input, and
project-owned mechanics.

## Scene structure

```text
Player : CharacterBody2D
├── CollisionShape2D
├── AnimatedSprite2D
├── MotionInput : NucleusMotionInput
└── Motor : NucleusCharacterMotor2D

World : Node2D
├── TileMapLayer (world geometry)
├── Player
└── Camera2D
    └── Follow : NucleusCameraFollow2D
```

## Physics configuration

In the `Player` inspector set:

```text
motion_mode = MOTION_MODE_GROUNDED
up_direction = Vector2.UP
```

Configure `Motor.body = Player` and `Motor.motion_input = MotionInput`.
Suggested starting values (illustrative, not universal balance):

```text
speed = 260 px/s
acceleration = 2200 px/s²
deceleration = 2600 px/s²
gravity_scale = 1.0
```

The motor applies world-space tangent velocity and only adds gravity when the
body is airborne. Godot manages collision response and floor detection.

## Author jump policy in the game

A jump is **not** a generic movement state. Gravity, jump height, buffers,
coyote time, double jumps, wall jump, drop-through and dash are product policy.
Write those rules in the consuming game, calling the motor's single velocity
impulse API when the jump is authorized:

```gdscript
extends Node

@export var body: CharacterBody2D
@export var motor: NucleusCharacterMotor2D
@export var jump_speed: float = 420.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump") and body.is_on_floor():
		motor.request_velocity_impulse(body.up_direction * jump_speed)
```

This simple example deliberately omits buffering and coyote time. Add them as
small game-owned policies when required, rather than introducing a platformer
motor into the public Nucleus API. Use a physical-frame queue if gameplay input
must be adjudicated on physics ticks.

## Animation and camera

Use `AnimatedSprite2D` for native frame playback, or `AnimationTree` with
`NucleusAnimationVelocityBinding2D` for state/blend parameters. Map actual
`body.velocity`/`body.is_on_floor()` to game-authored animation clips.

`NucleusCameraFollow2D` follows the Player while native `Camera2D` manages
smoothing, drag margins, limits and zoom. Existing `NucleusCameraFeedback2D`
and `NucleusLandingFeedback2D` add optional presentation effects.

## Validate your gameplay

1. Run and stop; check tangent movement and deceleration.
2. Jump with floor contact, jump off edges, and land on slopes.
3. Verify `move_and_slide()` is called by **only the motor**.
4. Confirm the same player can use keyboard and gamepad semantic input.
5. Test pause, respawn, terrain edges, moving platforms and camera boundaries.

For full shared wiring, read [`2d_foundation.md`](2d_foundation.md).
