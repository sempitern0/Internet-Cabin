# Tutorial: first steps with common Nucleus components

This guide is a cookbook for the most common scene-owned gameplay/UI components.

It is intentionally shallower than the technical contracts. The goal is to
answer:

> "What do I add to the scene first?"

## 1. Health, stamina, mana, oxygen, fuel: ValuePool

Use `NucleusValuePool` when a quantity has a minimum/current/maximum lifecycle.

Typical composition:

```text
Player
├── Health : NucleusValuePool
└── Stamina : NucleusValuePool
```

Use game code through the public pool API rather than mutating internal state.

Examples:

```gdscript
health.decrease(15.0)
health.increase(10.0)

if health.is_empty():
    die()
```

Add `NucleusRegenerator` as a child when the resource should recover over time.

Useful examples:

```text
health regeneration
stamina recovery
oxygen refill
shield recharge
vehicle energy
```

## 2. Damage: detection, payload, policy, storage

Keep these responsibilities separate:

```text
Hitbox/Hurtbox
    collision/detection
        ↓
HitPayload
    information about the hit
        ↓
DamageReceiver
    game-agnostic damage application policy
        ↓
ValuePool
    stored health/shield quantity
```

A weapon should not directly reach into another actor's private health variable
when the reusable damage pipeline fits the mechanic.

Keep game-specific damage formulas and combat design in the game.

## 3. Interaction

Use the interaction components when an actor needs to discover/select nearby
interactables.

A common shape is:

```text
Player
└── Interactor

Door / Chest / NPC
└── Interactable
```

Prefer local relationships and signals.

Do not introduce the global EventBus merely so a Player can interact with a
nearby Door that it already detects directly.

## 4. Finite state

Use `NucleusStateMachine` when an actor has explicit mutually meaningful states:

```text
idle
move
attack
stunned
dead
```

Let gameplay systems request/observe state.

Let animation consume state through the AnimationTree integration layer instead
of scattering animation calls through every state.

A state machine should not become a bag of unrelated boolean flags.

## 5. Cooldown

Add `NucleusCooldown` when many mechanics would otherwise recreate Timer
bookkeeping.

Example:

```text
FireAction
└── Cooldown
    duration = 0.25
```

Useful API:

```gdscript
if cooldown.is_ready():
    cooldown.start()

print(cooldown.get_time_left())
```

A `NucleusGameplayAction` can own/discover the cooldown as part of its
transaction.

## 6. MotionInput

Add `NucleusMotionInput` once per actor/controller that needs semantic movement
and look input.

It provides:

```text
get_move_vector()
get_look_vector()
get_action_strength()
is_action_pressed()
pointer delta consumption
optional NucleusLocalPlayerInput binding
```

Movement and camera components can then share the same input bridge.

This prevents separate "keyboard controller", "gamepad controller", and "camera
input" implementations from drifting apart.

## 7. 2D movement

Choose the motor by game shape:

```text
NucleusPlatformerMotor2D
    side-view gravity/jump platformer

NucleusTopDownMotor2D
    top-down movement
```

Keep collision in native `CharacterBody2D` and `CollisionShape2D`.

See:

[`platformer_2d.md`](platformer_2d.md)

## 8. 3D movement

For a standard 3D character:

```text
Player : CharacterBody3D
├── MotionInput
└── CharacterMotor3D
```

Configure the motor's `orientation_source` when movement should be camera
relative.

A third-person/orbital game can use a camera rig as that orientation source.

Keep swimming, vehicles, ladders, parkour, boats, and other movement modes
game-owned until a reusable boundary is proven.

## 9. Camera

Use native Camera2D/Camera3D features first.

Nucleus camera components add repeated composition such as:

```text
target follow/switching
third-person rig ownership
look input
mouse capture
FOV feedback
```

Do not wrap native camera zoom/limits/smoothing merely to make every property a
Nucleus API.

## 10. Pooling

Use `NucleusObjectPool`/`NucleusPoolable` for repeatedly created objects:

```text
projectiles
impact effects
enemy waves
pickups
temporary world effects
```

A Poolable automatically restores/deactivates reusable engine state.

Game-specific reset data belongs in `acquired`/`released` handling.

Do not pool objects simply because they exist. Pool when repeated allocation and
lifecycle churn is a real production concern.

## 11. Targeting

Use `NucleusTargetingAgent` when an actor repeatedly needs candidate collection
and target selection.

Examples:

```text
lock-on target
AI attack target
turret target
auto-aim candidate
```

Keep tactical selection policy game-specific when the generic targeting
component does not express it.

## 12. UI focus/navigation

For controller-friendly UI, start with normal Godot Controls and focus
neighbors/focus modes.

Use Nucleus focus/navigation helpers when repeated menus need the same production
behavior.

Keep:

```text
ui_accept
ui_cancel
ui_left/right/up/down
```

inside the active UI layer.

World gameplay should use semantic game actions.

## 13. Toasts and modals

Use scene-owned UI hosts for transient presentation.

Examples:

```text
controller connected
save completed
inventory full
network disconnected
confirmation dialog
```

Core systems should emit state/events. UI owns how those events are shown.

## 14. Component selection checklist

Before adding a component, ask:

1. Does native Godot already solve this cleanly?
2. Does Nucleus already own this concern?
3. Is the state scene-owned or cross-scene?
4. Is the behavior generic or project policy?
5. Will composition be clearer than inheritance?
6. Does the component remove repeated production wiring?

## Related docs

- [`../gameplay_foundation_quickstart.md`](../gameplay_foundation_quickstart.md)
- [`../pooling_targeting_quickstart.md`](../pooling_targeting_quickstart.md)
- [`../ui_quickstart.md`](../ui_quickstart.md)
- [`../../components/gameplay_foundation.md`](../../components/gameplay_foundation.md)
- [`../../components/gameplay_pooling_targeting.md`](../../components/gameplay_pooling_targeting.md)
- [`../../components/ui_and_accessibility.md`](../../components/ui_and_accessibility.md)
