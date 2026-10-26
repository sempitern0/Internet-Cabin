# Tutorial: Profile a Real Gameplay Workload

The goal is not to make a synthetic benchmark green. The goal is to identify the
real limiting subsystem on hardware the product supports, change one thing and
repeat the same workload.

## 1. Define the workload and target

Record:

```text
hardware
resolution / renderer / quality preset
target FPS
build type
player/entity counts
camera path or repeatable gameplay steps
```

Do not compare unrelated scenes or editor and standalone captures as though they
were equivalent.

## 2. Add a performance profile and sampler

Instance `performance_panel.tscn`, assign a game-owned
`NucleusPerformanceProfile`, and begin with the actual frame target. Add draw,
physics, navigation or memory budgets only after representative captures provide
evidence.

## 3. Triage the subsystem

Use Nucleus history/diagnostics to decide which native tool to open:

```text
CPU/script/frame → Godot Profiler
multiplayer traffic → Network Profiler
GPU resources → Video RAM
GPU bottleneck → platform/vendor profiler
```

Frame pacing p95 is usually more actionable than one isolated FPS sample.

## 4. Mark authored events

Trace spawn waves, first-use VFX, large saves, scene changes and other meaningful
operations. Keep custom probes cheap; do not traverse a large scene merely to
measure it.

## 5. Rendering investigation

When rendering is under pressure, run `NucleusRenderAudit.inspect(root)` to
shortlist repeated mesh/material groups, broad shadow casting or missing
visibility ranges. Confirm the finding in native rendering tools before switching
to MultiMesh, LOD or different shadow policy.

## 6. Physics investigation

Run `NucleusPhysicsAudit.inspect(root)` after native physics time/collision pairs
show pressure. Review awake bodies, disabled sleep, contact monitoring and active
Areas. Do not lower physics tick rate before understanding the workload.

## 7. AI/navigation investigation

Check path-request cadence and avoidance participation. Utility AI can use
`NucleusUpdateScheduler` for approximate decision cadence; movement/path-follow
integration stays on its normal physics owner.

## 8. First-use hitch investigation

Classify the hitch:

```text
I/O/dependencies → ResourceLoadQueue
pool instantiation → incremental pool prewarm
ordinary PackedScene startup → WarmupSequence
pipeline first draw → game-authored rendered warmup
```

Do not call hidden instantiation a shader precompiler.

## 9. Capture and compare

Save a baseline report, apply one bounded change, repeat the identical workload
and compare under equivalent context. Remove optimizations that add complexity
without measurable benefit.

Continue with [`runtime_optimization.md`](runtime_optimization.md) for a complete
composition example.
