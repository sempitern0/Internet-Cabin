# Build a reusable 2D character using Nucleus

Nucleus supplies reusable wiring, not a platformer or top-down preset. This
recipe also works for AI-controlled characters, scripted actors and online
proxies that share the same collision policy.

## 1. Scene-owned character

```text
Actor: CharacterBody2D
├── CollisionShape2D
├── VisualRoot: Node2D
│   └── AnimatedSprite2D / Sprite2D
├── MotionInput: NucleusMotionInput             optional for player actors
├── Motor: NucleusCharacterMotor2D
├── AnimationVelocity: NucleusAnimationVelocityBinding2D (if using AnimationTree)
└── game-owned action/state components as needed
```

Assign `Motor.body = Actor`. For player control assign `Motor.motion_input`.
`NucleusMotionInput` already handles semantic input and local multiplayer input.
Do not write a second script that calls `move_and_slide()` on the same actor.

## 2. Configure native physics

Choose **on `Actor`**, not on a new Nucleus class:

| Godot `motion_mode` | Motor handling | Typical game choice |
| --- | --- | --- |
| `MOTION_MODE_GROUNDED` | Tangent movement, gravity/up-axis preserved | Side view / floor-based actors |
| `MOTION_MODE_FLOATING` | Full XY movement without gravity | Arena / top-down / free movement |

Then tune `Motor.speed`, `acceleration`, `deceleration`, `gravity_scale` (grounded)
and `speed_multiplier`. The game owns `CollisionShape2D`, collision layers,
`up_direction`, slope policy and abilities.

## 3. Switch from input to other movement sources

For a scripted actor, derive a small node from `NucleusMotionSource2D` and
implement `get_desired_velocity(body, max_speed) -> Vector2`. Assign it to
`Motor.motion_source`. Enabled motion sources take priority over input; disabling
one allows the motor to fall back to the configured `MotionInput`.

For pathfinding, compose:

```text
Actor: CharacterBody2D
├── NavigationAgent2D
├── Follower: NucleusNavigationFollower2D
├── NavigationSource: NucleusNavigationMotionSource2D
└── Motor: NucleusCharacterMotor2D
```

Wire `Follower.agent`, `Follower.origin`, `NavigationSource.follower` and
`Motor.motion_source`. Make the follower physics priority lower than the motor
priority to publish the latest path velocity first.

This composition does not require a separate AI character motor or scene wizard.
The existing utility brain, state machine, targeting and action modules can be
added independently where the consuming game needs them.

## 4. Animation remains native

Two valid configurations:

- For frame sprites, keep a game-owned state-to-clip mapping and call
  `AnimatedSprite2D.play(clip_name)` only when the desired clip changes.
- For animation tracks/blend spaces, use Godot's `AnimationTree` plus
  `NucleusAnimationVelocityBinding2D` and optional
  `NucleusAnimationTreeStateBinding`.

The animation system observes the actual body velocity. It must not issue
additional movement or automatically choose attacks, death or jump mechanics.

## 5. Genre recipes

- [`platformer_2d.md`](platformer_2d.md): floor-based movement and jump rules.
- [`top_down_2d.md`](top_down_2d.md): full-XY movement, navigation and interaction.

These are documentation recipes, **not** two new Nucleus motor implementations.
