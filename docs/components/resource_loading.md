# Resource Loading Contract

`NucleusResourceLoadQueue` is a scene-owned adapter around Godot ResourceLoader for
explicit batches, bounded concurrency, progress, required/optional failure and
optional strong retention.

## Ownership

```text
ResourceLoader
    native import/cache/threaded dependency work

NucleusResourceLoadQueue
    explicit plan + admission + progress + retention

NucleusSceneFlow
    application-level scene replacement

game coordinator
    decides what to load, retain, warm and when to transition
```

There is no loading Autoload or global asset registry.

## Plans and entries

`NucleusLoadPlan` contains unique `NucleusLoadEntry` resources. Entries describe
path, optional display label/type hint, priority, visual weight, required status,
retention and sub-thread policy.

Start with low concurrency and `use_sub_threads = false`; raise them only after
profiling the target platform.

## Native cache and cancellation

The queue reuses retained Resources and Godot's native cache. Pending admissions
can be cancelled; ResourceLoader requests already running cannot be forcibly
terminated and are drained to a terminal engine state.

## Retention

Retention keeps a strong Resource reference for explicit later use. Releasing the
queue reference does not forcibly unload resources still referenced elsewhere.

## Loading presentation

Presentation observes queue signals or uses `NucleusUIResourceLoadBinding`. The
queue never owns art, retry UX or scene transitions. Progress coalescing is an
optional presentation concern, not a loader behavior change.

## First-use warmup

A loaded Resource can still produce main-thread cost during PackedScene
instantiation or startup. Compose `NucleusWarmupSequence` after loading when a
measured first-use scene hitch justifies it.

Use incremental pool prewarm for pooled scenes. Hidden warmup does not guarantee
GPU pipeline compilation; a renderer-specific first-draw hitch stays game-owned.

## Failure boundary

The queue reports loading failures. It does not decide fallback content, DLC
entitlement, network download, retry copy or fatal-error presentation.
