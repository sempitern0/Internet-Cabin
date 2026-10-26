# World Streaming Lifecycle Quickstart

Use `NucleusWorldStreamLifecycle` when a game already knows which stable world
regions it wants active but should not admit every load/unload operation at once.

## 1. Keep the heuristic game-owned

For example, an archipelago game may calculate:

```text
current island
adjacent islands
harbour ahead
one predictive navigation sector
```

Sort those stable IDs in the order they should become available.

Nucleus does not calculate that set.

## 2. Add scene-owned lifecycle

A typical scene:

```text
World
├── Player
├── WorldStreamLifecycle
├── ResourceLoadQueue
├── StreamedContent
└── GameStreamingCoordinator
```

Do not add another Autoload for this.

## 3. Supply desired regions

```gdscript
func refresh_desired_regions() -> void:
    var desired: Array[StringName] = [
        &"island_home",
        &"harbour_east",
        &"reef_02",
    ]

    world_stream.set_desired_regions(desired)
```

Order controls load admission.

## 4. Perform the actual work

Connect:

```gdscript
world_stream.load_requested.connect(_on_load_requested)
world_stream.unload_requested.connect(_on_unload_requested)
```

Both signals provide a `request_token`. Preserve it until the asynchronous work
completes; it protects retries from stale callbacks.

Your coordinator may use:

```text
NucleusResourceLoadQueue
PackedScene.instantiate()
procedural generation
object pools
native ResourceLoader
```

according to the region's content.

After success:

```gdscript
world_stream.mark_loaded(region_id, request_token)
```

and:

```gdscript
world_stream.mark_unloaded(region_id, request_token)
```

The lifecycle component never instantiates content itself.

## 5. Handle failures deliberately

On failure:

```gdscript
world_stream.mark_request_failed(
    region_id,
    request_token,
    NucleusWorldStreamLifecycle.Operation.LOAD,
    error,
)
```

Choose retry/backoff/fallback in game code.

When ready:

```gdscript
world_stream.retry_region(region_id)
```

There is no automatic retry loop.

## 6. Seed already-loaded content

If an authored starting island already exists:

```gdscript
world_stream.register_loaded_region(&"island_home")
```

Then include or exclude it from the desired set normally.

## 7. Tune admission only after profiling

Start with:

```text
max_load_requests_per_frame = 1
max_unload_requests_per_frame = 2
```

These limits only bound how many operations start. They do not guarantee that a
resource load, scene instantiation, terrain build, navigation update, or shader
upload fits the frame budget.

Use the Performance module and native profiler on representative hardware.

## 8. Validate churn

Run:

```text
examples/world/world_streaming_lifecycle_lab.tscn
```

Switch quickly between Route A, Route B, and Teleport.

Verify that:

```text
load admission stays bounded
stale loads are unloaded after completion
stale unloads reload when desired again
resident state converges to desired state
failed requests do not spin automatically
```

Then run the normal Nucleus validation suite.

## Technical contract

[`../components/world_streaming.md`](../components/world_streaming.md)
