# Tutorial: one 3D locomotion stack for player and AI

This tutorial builds an AI-controlled 3D character without creating an AI-specific
motor or animation controller.

The final architecture is:

```text
perception / Utility AI
        ↓
gameplay StateMachine
        ↓
NavigationFollower3D
        ↓
NavigationMotionSource3D
        ↓
CharacterMotor3D
        ↓
CharacterBody3D
       ↙           ↘
Facing             AnimationTree
```

## 1. Start from the same physical character shell

Create:

```text
Enemy : CharacterBody3D
├── CollisionShape3D
├── CharacterMotor3D
└── VisualRoot
```

Tune `CharacterMotor3D` exactly as you would for a player of the same movement
type.

This is important: acceleration, deceleration, gravity and collision behavior
should not depend on whether a human or an algorithm controls the actor.

## 2. Add native navigation

Add:

```text
NavigationAgent3D
```

Bake a valid navigation region in the world.

Configure radius/height/layers according to the actor.

Avoidance can remain off until a gameplay case proves it useful.

## 3. Add the path-intent layer

Add:

```text
NavigationFollower3D
```

Wire:

```text
agent = NavigationAgent3D
origin = Enemy
```

The follower computes desired/safe navigation velocity but does not move the
body.

## 4. Connect navigation to the shared motor

Add:

```text
NavigationMotionSource3D
```

Set:

```text
follower = NavigationFollower3D
```

Then assign it to:

```text
CharacterMotor3D.motion_source
```

At this point navigation and motor responsibilities are separate:

```text
Follower
    where should I move?

Motor
    how does this body physically move?
```

## 5. Let Nucleus wire the mundane parts

Instead of wiring everything manually, add:

```text
NucleusAICharacterSetup3D
```

Keep an authored `NavigationAgent3D`, then use:

```text
Auto Resolve AI Character
Wire Navigation Locomotion
```

By default the helper can create:

```text
CharacterMotor3D
NavigationFollower3D
NavigationMotionSource3D
AIStateMachineBridge
```

when their prerequisites exist.

It intentionally does not create:

```text
navigation mesh
utility decisions
states
targeting semantics
combat actions
animations
```

## 6. Verify speed ownership

The motor owns physical max speed:

```gdscript
motor.get_max_planar_speed()
```

The navigation motion source synchronizes:

```text
Follower.movement_speed
NavigationAgent3D.max_speed
```

to that value.

The setup helper also places the follower before the motor in physics priority,
avoiding an unnecessary frame of steering latency.

Test a runtime slow:

```gdscript
motor.set_speed_multiplier(0.5)
```

The next motion-source sample updates navigation speed too.

This prevents classic AI bugs where the path system thinks the actor moves at
5 m/s while gameplay has slowed it to 2.5 m/s.

## 7. Add a StateMachine

Create game states:

```text
Idle
Patrol
Chase
Attack
Flee
```

A Chase state should own target policy, not physics.

Example:

```gdscript
func enter(
	_previous: NucleusState,
	context: Dictionary,
) -> void:
	var target_point: Node = context.get(&"target_point")

	if target_point is Node3D:
		follower.follow_node(target_point)


func exit(_next: NucleusState) -> void:
	follower.clear_target()
```

No `body.velocity.x = ...` is needed.

## 8. Add Utility AI

Add:

```text
NucleusAIUtilityBrain
```

Create options for whatever the game actually needs.

For example:

```text
Patrol
    good with no target

Chase
    requires target

Attack
    target close enough

Flee
    low-health context
```

The UtilityBrain only chooses an intention.

## 9. Bridge utility decisions to states

Use the existing:

```text
NucleusAIStateMachineBridge
```

with `NucleusAIStateBinding` resources:

```text
patrol → Patrol
chase  → Chase
attack → Attack
flee   → Flee
```

The flow is now:

```text
context
→ Utility score
→ winning option
→ gameplay state
→ navigation goal/action
```

## 10. Share GameplayActions with the player

Suppose both player and enemy can perform a generic melee attack.

Use one action composition pattern:

```text
Attack : NucleusGameplayAction
├── range/state requirement
├── cooldown
├── cost if applicable
├── damage effect
└── animation OneShot effect
```

Player input can call it.

The AI Attack state can call the same action.

The actor type does not need a separate combat implementation merely because the
request came from AI.

## 11. Add movement-facing presentation

For patrol/chase:

```text
MovementFacing3D.mode = MOVEMENT
```

The visual pivot follows motor movement.

This still works even though there is no `MotionInput`, because facing listens to
the shared motor.

## 12. Add target-facing combat

For a lock-on enemy:

```gdscript
facing.set_facing_target(target_point)
```

Now:

```text
navigation says move left
facing says keep looking at target
```

The character can strafe around the opponent.

When leaving combat:

```gdscript
facing.set_mode(
	NucleusMovementFacing3D.Mode.MOVEMENT
)
```

## 13. Reuse the exact same AnimationTree approach

Add/import the normal character animation stack:

```text
AnimationTree
AnimationVelocity3D
OneShotController
AnimationQualityController3D
```

Do not create `EnemyAnimationController`.

The binding reads:

```text
CharacterBody3D.velocity
```

so locomotion animation is independent of whether movement came from player
input, navigation, replay or autopilot.

## 14. Directional combat animation

When using target-facing movement, use the directional BlendSpace2D pipeline.

Example:

```text
actor faces target

actual local body velocity
    X < 0 → strafe left
    X > 0 → strafe right
    Z direction → forward/backward
```

The AI does not choose `StrafeLeft`.

The animation graph derives it from real motion.

## 15. Actions drive OneShots

An AI Attack state should normally request gameplay action execution:

```gdscript
attack_action.try_execute(context)
```

Animation OneShots are triggered by the action/effect layer.

That means:

```text
AI decides Attack
    ↓
GameplayAction validates and commits
    ↓
Animation OneShot presents it
```

not:

```text
AI plays Attack animation
    ↓
game guesses whether damage happened
```

## 16. Jump and navigation links

The shared motor already exposes:

```gdscript
motor.request_jump()
```

A navigation-link handler can translate authored link semantics into:

```text
Jump action/state
Vault action/state
Door interaction
Ladder state
Teleport
```

Do not make every `NavigationLink3D` imply jump.

## 17. Think slowly, move smoothly

Do not run the full decision stack every physics frame.

A practical starting point:

```text
UtilityBrain evaluation
    0.25 s

moving-target repath
    0.20–0.50 s + displacement threshold

CharacterMotor3D
    every physics tick

animation
    quality-dependent
```

The latest navigation velocity continues through the motor while the brain waits
for its next evaluation.

## 18. Stagger many brains

For dozens or hundreds of NPCs, assign:

```text
NucleusUpdateScheduler
```

to UtilityBrains.

Automatic phase staggering prevents every NPC from evaluating on the same frame.

The report helper flags interval-driven brains that are not scheduler-backed as a
performance note.

## 19. Treat avoidance as a budget

Native RVO is useful for close groups but not free.

A reasonable product policy can be:

```text
near combat agents
    avoidance on

distant/path-isolated agents
    avoidance off
```

Nucleus does not silently toggle this based on distance because crowd semantics
belong to the game.

## 20. Combine with animation quality

For a weak PC:

```text
local player
    animation FULL

near enemies
    FULL or REDUCED

mid-distance enemies
    REDUCED

background actors
    MINIMAL
```

Utility evaluation can also be less frequent for unimportant actors.

Do not reduce `CharacterMotor3D` physics cadence merely because the AI brain is
low frequency.

## 21. Validate with the setup report

Press:

```text
Print AI Character Report
```

Fix structural warnings first.

Then profile representative scenes:

```text
1 actor
10 actors
50 actors
crowded avoidance case
combat target-facing case
low animation quality
```

Measure before adding more scheduling/LOD policy.

## 22. Final ownership

A healthy reusable architecture should read:

```text
Game AI
    chooses intention and behavior semantics

Nucleus AI/navigation
    reusable decision/path adapters

Nucleus movement
    common physical locomotion

Godot
    NavigationServer / CharacterBody / AnimationTree

Game
    owns combat, tactics, content and quality mapping
```

That is why AI-controlled and player-controlled characters can share almost all
of their locomotion and presentation stack.
