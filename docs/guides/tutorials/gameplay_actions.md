# Tutorial: create input actions and GameplayActions

Godot and Nucleus both use the word "action", but they solve different problems.

```text
InputMap action
    "Which semantic input did the player request?"

NucleusGameplayAction
    "Can this gameplay operation execute, what does it cost,
     what cooldown applies, and what effects commit?"
```

A project often uses both.

## Part A — create an InputMap action

Suppose the game needs an ability named:

```text
ability_primary
```

### 1. Open Input Map

In Godot:

```text
Project
→ Project Settings
→ Input Map
```

Add:

```text
ability_primary
```

### 2. Add default physical bindings

For example:

```text
Keyboard: Q
Gamepad: a face/shoulder button chosen by the game
```

The exact physical default is game policy.

Gameplay code should now ask for:

```gdscript
Input.is_action_just_pressed(&"ability_primary")
```

not for `KEY_Q` or a joystick button index.

### 3. Add it to the game's rebinding UI

Use the pattern in:

[`bindings.md`](bindings.md)

Once rebound, gameplay still reads the same `ability_primary` action.

## Part B — turn that request into a GameplayAction

Create this under the actor:

```text
Player
├── MotionInput
└── PrimaryAbility : Node
    ├── Input : Node
    └── Cooldown : Node
```

Assign:

```text
PrimaryAbility
    script = NucleusGameplayAction
    action_id = ability_primary

Input
    script = NucleusGameplayActionInput
    input_action = ability_primary

Cooldown
    script = NucleusCooldown
    duration = 0.5
```

Assign `PrimaryAbility.cooldown` explicitly or let the action discover the
single `NucleusCooldown` under its `parts_root`.

Assign `Input.motion_input` to the actor's `NucleusMotionInput` when local-player
device ownership matters.

That makes the same action work with the per-player input stream already used by
movement/camera.

## Part C — execute game-specific behavior

`NucleusGameplayAction` intentionally does not know what "primary ability" means
for your game.

Connect:

```text
PrimaryAbility.executed
```

from the actor script:

```gdscript
@onready var primary_ability: NucleusGameplayAction = %PrimaryAbility


func _ready() -> void:
    primary_ability.executed.connect(_on_primary_ability)


func _on_primary_ability(context: Dictionary) -> void:
    _spawn_projectile(context)
```

Nucleus owns the transaction. The game owns projectile content and combat rules.

## Part D — add a resource cost

Suppose the actor has:

```text
Stamina : NucleusValuePool
```

Add under the action:

```text
PrimaryAbility
├── Input
├── Cooldown
└── StaminaCost : NucleusValuePoolCost
```

Configure:

```text
target_pool = Stamina
amount      = 20
reserve     = 0
```

The action now rejects execution when the cost cannot be paid.

The normal execution shape becomes:

```text
input request
→ validate action
→ validate requirements
→ validate costs
→ validate effects
→ pay costs
→ start cooldown
→ commit
→ apply effects
→ emit executed
```

Do not subtract stamina again from `_on_primary_ability()`. The cost component
already owns that mutation.

## Part E — add requirements

A requirement answers:

```text
"May this action execute right now?"
```

Examples include:

- actor must be in the correct state;
- target must exist;
- required inventory item must exist;
- status/tag must not block the action;
- game-specific line-of-sight or environment rules.

Requirements should be side-effect free.

If the rule is reusable, create/compose a small
`NucleusActionRequirement` rather than subclassing the whole action transaction.

## Part F — add effects

An effect answers:

```text
"What reusable mutation happens after the action commits?"
```

Nucleus includes reusable effects for several gameplay systems.

A project-specific effect can subclass `NucleusActionEffect`.

Keep irreversible mutation out of requirements and costs' affordability checks.

## Part G — execute an action without player input

AI, UI, scripts, and networking can call the same action directly:

```gdscript
var error: Error = primary_ability.try_execute({
    "source": enemy_ai,
    "target": current_target,
})

if error != OK:
    return
```

This is why input is an adapter to the action rather than the action itself.

The same transaction can be triggered by:

```text
player input
AI
UI button
network-authoritative request
scripted sequence
```

## Part H — group actions with ActionSet

When an actor has many actions, add a `NucleusActionSet`.

It gives stable lookup/coordination for systems such as:

```text
AI
UI
save integration
status-effect action blocking
code that executes by action_id
```

Direct Node references remain valid; do not introduce an ActionSet when the
actor has one simple action and no registry use case.

## Input action versus GameplayAction: practical examples

### Jump

For a simple platformer jump:

```text
InputMap "jump"
→ NucleusPlatformerMotor2D.jump_action
```

A full `NucleusGameplayAction` is unnecessary unless jump needs transactional
requirements/costs/cooldown/effects.

### Healing potion

```text
InputMap "use_item"
→ GameplayAction
    requirement: potion exists
    cost: consume potion
    effect: restore health
```

A GameplayAction is useful.

### Door interaction

A simple nearby interactable may only need the interaction component.

If opening the door additionally has keys, costs, cooldowns, authority checks,
or reusable effects, a GameplayAction can become useful.

## Common mistakes

- treating an InputMap action as the complete gameplay mechanic;
- checking physical keys inside an ability;
- subtracting a resource both in an ActionCost and in game code;
- doing irreversible work in a requirement;
- building one giant GameplayAction subclass for every ability;
- using `ui_accept`/`ui_cancel` for world gameplay;
- making AI bypass the same validation path used by the player.

## Related docs

- [`../actions_attributes_status_quickstart.md`](../actions_attributes_status_quickstart.md)
- [`gameplay_actions_attributes_status.md`](../../components/gameplay_actions_attributes_status.md)
- [`platformer_2d.md`](platformer_2d.md)
