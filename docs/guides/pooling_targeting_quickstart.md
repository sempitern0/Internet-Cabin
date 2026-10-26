# Pooling and Targeting Quickstart

## Object pooling

Place one `NucleusObjectPool` per reusable scene/type in the owning gameplay
scope. Do not add a global pool registry solely for access convenience.

Lifecycle:

```text
reserve
→ set transform/context
→ activate
→ use
→ release/reset
```

For small capacities, synchronous `prewarm()` is fine. For large capacities:

```gdscript
await pool.prewarm_incremental(200, 8)
```

or configure `auto_prewarm_instances_per_frame`. This spreads instantiation cost
without changing pool ownership.

Pool only when repeated create/free churn is measured or clearly expected; rare
objects are often simpler as normal scenes.

## Targeting

`NucleusTargetingAgent` owns candidates, current selection and lock state. Sensors
own discovery sources; filters own validity; scorers own ranking.

```text
Area2D/3D sensor
→ source-owned candidate registry
→ filters
→ scorers
→ current target
```

Do not perform another physics query inside every action when the targeting owner
already has the required selection.

## Performance composition

Target rescoring or expensive awareness that tolerates bounded latency can use
`NucleusUpdateScheduler`. Per-frame aiming/movement and correctness-critical hit
logic should not.

Large inactive actor subtrees may compose `NucleusActivityGate` when the game has
an explicit relevance policy.
