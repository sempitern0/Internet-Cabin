# Tutorial: Bootstrap Loading, Presentation and First-use Warmup

This tutorial composes a scene-owned resource batch, custom loading presentation,
scene hand-off and optional warmup.

## 1. Scene ownership

```text
Bootstrap
├── ResourceLoadQueue
├── WarmupSequence
├── LoadingPresentation
└── BootstrapCoordinator
```

Presentation observes state. It does not own ResourceLoader or scene replacement.

## 2. Author a load plan

Use `NucleusLoadEntry` resources with meaningful priority/weight and mark only
Resources that truly require retention. Required failures fail the batch;
optional failures stay observable without automatically failing it.

## 3. Bind loading presentation

Use `NucleusUIResourceLoadBinding` or game-owned signal handlers for weighted
progress, processed count and current item. Enable `coalesce_progress_updates`
only when progress writes are frequent enough to justify one-frame deferred
coalescing.

## 4. Hand off a retained scene

Retrieve the retained `PackedScene` and call
`NucleusSceneFlow.change_scene_to_packed()` so the target is not loaded again.

## 5. Warm expensive first-use scenes

After I/O settles, run a `NucleusWarmupPlan` for known scenes that hitch on first
instantiation.

Prefer `INSTANTIATE_ONLY`. Use `ENTER_TREE_INACTIVE` only when `_ready()` side
effects are explicitly safe during loading.

Do not use generic warmup for object pools; use `prewarm_incremental()` instead.

## 6. Understand the boundary

Threaded loading can still be followed by main-thread instantiation, GPU upload
or pipeline compilation. Hidden scene warmup does not guarantee every renderer
pipeline is compiled. If a first-draw hitch remains and pipeline counters confirm
it, use a small game-authored rendered warmup scene.

## 7. Runtime anticipation

The same queue can preload an explicit bundle while gameplay continues. The game
decides *what* is likely to be needed and when retention should end; Nucleus does
not implement an asset database or predictive loader.

## Validation

Run the headless suite plus `tests/smoke/resource_loading_smoke.tscn`. Profile the
real target hardware when changing concurrency, sub-thread usage, warmup batch
size or retention policy.
