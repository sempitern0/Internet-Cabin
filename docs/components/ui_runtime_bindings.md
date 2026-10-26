# UI Runtime Bindings Contract

Runtime bindings are scene-owned adapters that project existing Nucleus state into
existing Godot Controls. They observe; they do not become gameplay authority.

## ValuePool progress

`NucleusUIValuePoolProgressBinding` maps one `NucleusValuePool` ratio into
`NucleusUIProgressFeedback`. Gameplay owns health/stamina/etc.; the binding owns
only presentation synchronization.

## Resource-load presentation

`NucleusUIResourceLoadBinding` observes `NucleusResourceLoadQueue` lifecycle and
can drive a `Range`, `NucleusUIProgressFeedback`, count Label and current-item
Label.

`coalesce_progress_updates` is opt-in. When enabled, intermediate progress writes
within one frame are collapsed; start/finish lifecycle presentation remains
immediate.

## Scene-load presentation

`NucleusUISceneLoadBinding` projects `NucleusSceneFlow` progress into one progress
presentation and emits local loading lifecycle signals. It does not choose the
destination, retry policy or player-facing loading copy.

## Generic refresh coalescing

`NucleusUIRefreshCoalescer` is a reusable same-frame invalidation merger for
expensive panels that observe several signals:

```text
signal A ─┐
signal B ─┼→ request_refresh() → one deferred refresh_due
signal C ─┘
```

Use `flush_now()` when a consumer explicitly needs immediate synchronization.
Do not use coalescing for focus, confirmation or modal ownership when latency
changes interaction correctness.

## Performance rule

Bindings are signal-driven. Do not add per-frame HUD polling merely to keep a
Control synchronized with an owner that already emits changes.

## Animated value edge cases

`NucleusUIAnimatedValue` remains presentation-only. `set_value()` replaces an
in-flight Tween with the newest target; a synchronous `animated=false` request
snaps immediately. When `NucleusUIMotion.get_duration()` resolves to zero,
including reduced-motion policy, even `animated=true` snaps synchronously,
emits its completion once, and does not create a zero-duration deferred Tween.
The underlying gameplay owner remains authoritative. Regression coverage:
`tests/headless/composition_contracts_test.gd`.
