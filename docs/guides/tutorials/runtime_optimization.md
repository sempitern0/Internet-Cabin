# Tutorial: Smooth a Busy Gameplay Scene

This tutorial applies Nucleus runtime-efficiency tools to a representative actor
scene without changing gameplay semantics.

## 1. Start with evidence

Run the representative workload with `NucleusPerformanceSampler`. Record target
FPS, p95 pacing, physics/navigation time and relevant authored trace markers.
Do not add optimization components to an otherwise healthy scene.

## 2. Stagger low-frequency decisions

Add one scene-owned scheduler:

```text
World
├── UpdateScheduler : NucleusUpdateScheduler
└── NPCs
```

Assign Utility AI brains to that scheduler with an evaluation interval such as
`0.25`. Leave `evaluation_phase = -1` so simultaneous NPC creation does not align
all future evaluations.

Keep movement and physics integration on their normal owners.

## 3. Gate explicitly irrelevant actors

Add `NucleusActivityGate` to an actor only when the game has a clear relevance
policy. For example, a project-owned coordinator may call:

```gdscript
gate.set_active(distance_to_player <= ai_simulation_radius)
```

Start by managing only process mode. Add visibility, particles or rigid-body sleep
only when that behavior is intentionally part of the relevance policy.

## 4. Prewarm a projectile/effect pool

For a large pool:

```gdscript
await projectile_pool.prewarm_incremental(160, 8)
```

Observe `prewarm_progress` in loading presentation when useful. Do not prewarm
arbitrary maximum capacities that the measured workload never reaches.

## 5. Audit render/physics structure

After the sampler/native profiler identifies pressure:

```gdscript
for diagnostic in NucleusRenderAudit.inspect(world):
    print(diagnostic.to_dictionary())

for diagnostic in NucleusPhysicsAudit.inspect(world):
    print(diagnostic.to_dictionary())
```

Use findings as a shortlist. Confirm repeated meshes, shadow density, visibility
ranges, awake rigid bodies, sleep policy and monitoring Areas in the native tools
before restructuring the scene.

## 6. Move first-use scene work into loading

Create `NucleusWarmupEntry` resources for expensive scenes that hitch the first
time they are instantiated. Put them in a `NucleusWarmupPlan` and run a
`NucleusWarmupSequence` during an existing loading phase.

Use `ENTER_TREE_INACTIVE` only for scenes whose `_ready()` logic is safe during
warmup. For pooled scenes, prefer pool prewarm.

If the hitch is specifically first-draw GPU pipeline compilation, author a small
rendered warmup scene instead of assuming hidden instantiation can force it.

## 7. Protect important one-shot audio

Give important `NucleusAudioCue` resources a higher `voice_priority`. When the
shared non-positional pool is full, an incoming low-priority sound can be rejected
instead of stealing a more important voice.

The default priority `0` preserves oldest-first historical behavior.

## 8. Coalesce expensive HUD refreshes

When several runtime signals invalidate the same presentation:

```gdscript
source_a.changed.connect(coalescer.request_refresh)
source_b.changed.connect(coalescer.request_refresh)
coalescer.refresh_due.connect(_refresh_panel)
```

Keep focus/confirmation/modal state immediate.

## 9. Budget a large save snapshot

```gdscript
var job := save_session.create_capture_job()

while not job.is_completed():
    job.step(8)
    await get_tree().process_frame

var payload := job.take_snapshot()
```

This spreads participant capture, not arbitrary Node work onto worker threads.
Pause/quit saves should remain synchronous.

## 10. Repeat the same workload

Capture a second performance report under equivalent execution context and
compare it to the baseline. Keep an optimization only when the measured workload
improves without violating gameplay or product constraints.

Technical contract: [`../../components/runtime_optimization.md`](../../components/runtime_optimization.md).
