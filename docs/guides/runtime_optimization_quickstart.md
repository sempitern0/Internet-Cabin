# Runtime Optimization Quickstart

This guide covers general runtime efficiency outside terrain and world streaming.
All tools are opt-in; none automatically changes game quality or simulation rules.

## Stagger low-frequency work

Use `NucleusUpdateScheduler` for approximate-cadence tasks such as Utility AI,
awareness checks, target rescoring, secondary HUD refresh or diagnostics.

```gdscript
var token := scheduler.register_task(
    _refresh_awareness,
    0.25,
)
```

A negative phase auto-staggers registrations. The scheduler caps callbacks and
can enforce a wall-clock admission budget. Missed intervals execute once; they
are not replayed as catch-up work.

Do **not** schedule player input, CharacterBody integration, hit resolution or
other frame/fixed-step correctness work this way.

## Gate irrelevant subtrees

`NucleusActivityGate` applies an explicit active/inactive state. The game decides
what "relevant" means.

```gdscript
gate.set_active(distance_to_player < simulation_radius)
```

Process mode is managed by default; visibility, particles and rigid-body sleep
are opt-in because they can change behavior or presentation.

## Prewarm pools gradually

```gdscript
await pool.prewarm_incremental(200, 8)
```

or set `auto_prewarm_instances_per_frame` for scene-authored startup. Keep normal
`prewarm()` when a synchronous setup is intentionally small.

## Audit rendering and physics

After the performance sampler/native profiler shows pressure:

```gdscript
var render_findings := NucleusRenderAudit.inspect(root)
var physics_findings := NucleusPhysicsAudit.inspect(root)
```

Audits return diagnostics; they never rewrite the scene. Treat repeated meshes,
shadows, visibility ranges, awake bodies, disabled sleep, contact monitoring and
Area monitoring as investigation candidates, not automatic errors.

## Warm first-use scenes

Use `NucleusWarmupPlan` + `NucleusWarmupSequence` for explicit PackedScene
instantiation during loading. Prefer `INSTANTIATE_ONLY`; use
`ENTER_TREE_INACTIVE` only when the scene's `_ready()` side effects are safe.

Hidden instantiation does not guarantee shader/pipeline compilation. A GPU hitch
may require a small game-authored rendered warmup scene after measurement proves
that pipeline first-use is the cause.

## Budget audio, UI and save capture

- `NucleusAudioCue.voice_priority` protects important non-positional one-shots
  when the shared pool is saturated.
- `NucleusUIRefreshCoalescer` merges same-frame refresh bursts.
- `NucleusSaveCaptureJob` captures a bounded number of save participants per
  rendered frame while keeping Node access on the main thread.

Lifecycle autosaves on pause/quit remain synchronous because another frame is not
guaranteed.

## Validate improvement

Always repeat the **same** workload and compare the same target context after a
change. Architecture is not performance evidence.

Hands-on: [`tutorials/runtime_optimization.md`](tutorials/runtime_optimization.md).
Canonical contract: [`../components/runtime_optimization.md`](../components/runtime_optimization.md).
