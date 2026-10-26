# Actions, Attributes, and Status Effects Quickstart

For a step-by-step explanation of InputMap actions versus
`NucleusGameplayAction`, follow:

[`tutorials/gameplay_actions.md`](tutorials/gameplay_actions.md)

## GameplayAction

Create/configure a `NucleusGameplayAction`, then compose the pieces it needs:

```text
requirements
costs
effects
context providers
optional blockers
```

Remember the execution order:

```text
requirements
→ costs
→ effect prevalidation
→ pay
→ cooldown
→ commit
→ effects
```

Do not perform irreversible work from requirement checks.

Input is only one adapter. Player input, AI, UI, networking, or scripts can all
request the same action transaction.

## Attributes

Define the base attribute, then add modifiers from explicit sources.

Use source ownership so removing an equipment item/status/buff removes only its
own modifiers.

Use bindings when an attribute drives another component property.

## Status effects

Use the status container/definitions for duration, stacking, and periodic
behavior.

When a status changes a ValuePool, use the provided ticker/integration rather
than mutating the pool's internal value.

## Common composition

```text
GameplayAction
├── State requirement
├── ValuePool cost
├── Target requirement
├── State/Animation/ValuePool effects
└── game-specific effects

StatusEffectContainer
└── modifier/ticker integrations
```

Prefer adding a small new requirement/cost/effect over subclassing the complete
action transaction.
