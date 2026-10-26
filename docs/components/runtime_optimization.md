# Runtime Optimization Contract

## Scope

This is the canonical Nucleus contract for general runtime-efficiency tools
outside terrain and world streaming.

```text
components/gameplay/timing
components/gameplay/lifecycle
components/gameplay/pooling
modules/ai integration
modules/performance audits
core/loading warmup
core/audio one-shot budgeting
components/ui/data refresh coalescing
core/save capture budgeting
```

No `OptimizationManager` or optimization Autoload exists. Godot remains
authoritative for frame scheduling, rendering, physics, navigation, resources and
profiling.

## Staggered update scheduling

`NucleusUpdateScheduler` is scene-owned and intended only for approximate-cadence
work such as Utility AI decisions, awareness checks, target rescoring, ambient
simulation and low-frequency diagnostics.

Tasks declare interval, optional phase and priority. Negative phase uses automatic
staggering. The scheduler caps callbacks per frame and may enforce a wall-clock
admission budget.

A delayed task executes once and schedules its next run from the current clock;
missed intervals are not replayed. Therefore it must not own fixed-step gameplay,
input, movement integration, hit resolution or frame-exact animation events.

`NucleusScheduledUpdate` exposes one task as an Inspector-friendly `tick(elapsed)`
component.

## Activity gating

`NucleusActivityGate` applies an explicit active/inactive state to a project-owned
target. It does not infer camera distance, combat state or network relevance.

Process mode is managed by default. Visibility, particle emission and rigid-body
sleep are opt-in. The component captures authored baseline state and restores it
on reactivation.

## Incremental object-pool prewarm

`NucleusObjectPool.prewarm()` remains synchronous. For larger capacities use
`prewarm_incremental(target_total, instances_per_frame)` or the matching
auto-prewarm export.

`prewarm_progress` exposes loading progress without polling. Pooling is still
optional: do not pool rare objects merely because the API exists.

## Utility AI scheduling

`NucleusAIUtilityBrain` may use a `NucleusUpdateScheduler`. With scheduler +
positive evaluation interval, automatic evaluation leaves per-physics polling and
uses the scheduled cadence. Auto phase prevents many simultaneously spawned
brains from aligning future decisions.

Context-change requests can make the task eligible for the next dispatch. Without
a scheduler, existing physics-driven behavior remains available.

## Render audit

`NucleusRenderAudit.inspect(root)` returns `NucleusPerformanceDiagnostic` findings
for structural candidates such as large repeated mesh/material groups, broad
shadow casting and missing visibility-range ends.

A finding is not an instruction to mutate the scene. Confirm rendering pressure
with the sampler/native tooling before changing MultiMesh, LOD, visibility or
shadow policy.

## Physics audit

`NucleusPhysicsAudit.inspect(root)` reports broad candidates such as many awake
rigid bodies, disabled sleeping, widespread contact monitoring and actively
monitoring Areas.

It never changes collision masks, sleep, monitoring, physics tick rate or Jolt
configuration.

## First-use warmup

`NucleusWarmupPlan` contains `NucleusWarmupEntry` resources and is executed by a
scene-owned `NucleusWarmupSequence` with bounded instances per rendered frame.

Modes:

```text
INSTANTIATE_ONLY
ENTER_TREE_INACTIVE
```

The second mode executes normal tree/ready lifecycle and is therefore safe only
for explicitly warmup-compatible scenes.

Hidden instantiation cannot guarantee GPU pipeline compilation. A renderer-first
hitch may require a project-authored rendered warmup after profiler/pipeline
evidence identifies that cause.

## Audio voice budgeting

The shared non-positional one-shot pool accepts integer voice priorities.
`NucleusAudioCue.voice_priority` carries authored policy. At capacity, the pool
chooses the oldest voice among the lowest active priority; a lower-priority new
request is rejected rather than stealing a more important voice.

Default priority `0` preserves equal-priority oldest-first behavior. Positional
2D/3D audio remains scene-owned.

## UI refresh coalescing

`NucleusUIRefreshCoalescer` collapses several same-frame invalidations into one
deferred `refresh_due`. `flush_now()` provides an explicit immediate path.

Do not coalesce focus, confirmation or modal ownership when one-frame latency
changes correctness. `NucleusUIResourceLoadBinding` exposes optional progress
coalescing for noisy loading updates.

## Save capture budgeting

`NucleusSaveCaptureJob` snapshots the participant callback set and captures a
bounded number of participants per step. `capture_snapshot_incremental()` and the
incremental save helpers yield between batches.

Participant capture remains on the main thread because callbacks may read Nodes.
Application pause/quit autosaves remain synchronous because another frame is not
guaranteed.

## Measurement contract

Use `NucleusPerformanceSampler` and native Godot profilers to establish evidence.
The preferred loop is:

```text
repeatable workload
→ capture baseline
→ identify subsystem pressure
→ apply one bounded primitive
→ repeat same workload
→ compare report
```

Architecture alone is never a performance result.
