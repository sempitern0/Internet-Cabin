# Baseline Architecture

## Dependency direction

Nucleus follows this general direction:

```text
Godot native APIs
        ↑
Core infrastructure
        ↑
scene-owned Components
        ↑
game-specific composition
```

Optional modules sit beside the baseline and are adopted explicitly.

## Autoload policy

An Autoload is justified by genuine cross-scene lifetime, not convenience.

The default project currently loads:

```text
NucleusApp
NucleusSettings
NucleusInput
NucleusAudio
NucleusSave
NucleusSceneFlow
```

EventBus, networking, development tools, and other optional modules remain
explicit opt-ins.

## Composition

Game-facing systems prefer small Nodes/Resources with explicit references,
signals, and source ownership.

Examples:

```text
ValuePool + DamageReceiver + Regenerator
StateMachine + AnimationTree binding
GameplayAction + requirements + costs + effects
Attribute + independent modifier sources
TargetingAgent + sensors + filters + scorers
Camera + independent feedback sources
```

This makes mechanics removable and prevents inheritance trees from encoding
every possible combination.

## Native Godot ownership

Nucleus adds reusable policy around native features rather than shadowing them:

```text
Input/InputMap
AudioServer/audio buses
TranslationServer
CharacterBody2D/3D
Area2D/3D
Camera2D/3D
AnimationPlayer / AnimationTree / Skeleton3D
Tween
MultiplayerAPI
FileAccess/ConfigFile/Resources
```

When Godot already has a strong abstraction, use it directly.

## Communication

Prefer, in order:

1. direct call/reference when ownership is explicit;
2. local signal for observation;
3. source-owned registration for many producers;
4. optional EventBus only for genuine decoupling.

There is no Service Locator.

## Persistence

Runtime objects own behavior. Save/settings layers persist plain stable data.
Live Nodes, Callables, timers, and transient overlap/feedback state should not be
treated as durable data.

## Baseline scope

The baseline is intentionally broad enough to start real projects while still
leaving game-specific mechanics, content, art pipelines, backend policy, and
product decisions to the consuming game. New reusable behavior should be driven
by repeated production friction rather than feature-count goals.
