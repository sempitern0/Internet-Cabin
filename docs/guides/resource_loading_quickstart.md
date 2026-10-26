# Resource Loading Quickstart

Use `NucleusResourceLoadQueue` when a scene/session needs an explicit batch of
Resources prepared with bounded concurrency and observable progress. For one
ordinary scene replacement, prefer `NucleusSceneFlow.change_scene()`.

## Load plans

Author a `NucleusLoadPlan` containing `NucleusLoadEntry` resources with:

```text
path / display_name / type_hint
priority / weight
required / retain
use_sub_threads
```

A typical bootstrap scene owns the queue:

```text
Bootstrap
├── ResourceLoadQueue
├── LoadingUI
└── BootstrapCoordinator
```

Start with:

```text
max_concurrent_requests = 2
use_sub_threads = false
```

and increase only after profiling.

## Presentation

`NucleusUIResourceLoadBinding` can project progress/count/current item into
existing Controls. Presentation does not own ResourceLoader, retries or scene
replacement.

For very frequent progress signals, `coalesce_progress_updates` can collapse
same-frame intermediate writes while start/finish events remain immediate.

## Retention and hand-off

When a loaded `PackedScene` is retained, hand it directly to:

```gdscript
NucleusSceneFlow.change_scene_to_packed(scene, scene_path)
```

so the target is not loaded a second time.

Releasing queue retention only drops the queue's strong reference; Godot keeps a
Resource alive while another owner still references it.

## First-use warmup after loading

Threaded I/O completion does not make instantiation or first-use setup free.
After a plan completes, an explicit `NucleusWarmupSequence` can amortize selected
PackedScene instantiation across frames.

Use object-pool incremental prewarm for pooled scenes instead of duplicating them
through a generic warmup plan.

Hidden scene instantiation does not guarantee GPU pipeline compilation; use a
rendered warmup scene only when profiling proves that first-draw pipeline work is
the hitch.

Hands-on: [`tutorials/resource_loading.md`](tutorials/resource_loading.md).
