# Tutorial: budget streamed world materialization

This tutorial builds the reusable boundary required for islands, sectors, rooms,
large procedural patches and other content whose creation cannot safely happen in
one frame.

The final ownership is:

```text
game
    decides desired stable region IDs
        ↓
NucleusWorldStreamLifecycle
    admits load/unload request tokens
        ↓
game
    creates the correct job for the region
        ↓
NucleusWorldStreamMaterializationBinding
        ↓
NucleusMaterializationQueue
    bounded main-thread steps
        ↓
game
    owns the completed region content
```

## 1. Create the lifecycle

Add:

```text
NucleusWorldStreamLifecycle
```

Start conservatively:

```text
max_load_requests_per_frame = 1
max_unload_requests_per_frame = 2
```

This bounds request admission only.

## 2. Create the materialization queue

Add:

```text
NucleusMaterializationQueue
```

A reasonable first profiling configuration is:

```text
max_steps_per_frame = 4
frame_budget_usec = 2000
```

This means at most four job steps are attempted per frame, with the elapsed-time
budget checked between steps.

It is not a hard real-time preemption system.

## 3. Add the optional binding

Add:

```text
NucleusWorldStreamMaterializationBinding
```

Assign:

```text
lifecycle
queue
cancel_stale_requests = true
```

The binding handles current request-token acknowledgements.

It does not decide what a region contains.

## 4. Define game-owned region descriptors

Example:

```gdscript
var regions := {
	&"island_03": {
		"position": Vector3(1200.0, 0.0, -500.0),
		"profile": island_profile,
		"material": tropical_material,
	},
}
```

Nucleus does not own this dictionary/schema.

A save system can persist whatever stable descriptor the game requires.

## 5. Feed desired region IDs

The game computes desire from player position, camera, route, portal graph or
another product rule:

```gdscript
lifecycle.set_desired_regions([
	&"island_03",
	&"island_04",
])
```

Order represents game-owned load priority.

## 6. Respond to load admission

Connect:

```text
load_requested(region_id, request_token)
```

Build the appropriate job.

For terrain:

```gdscript
func _on_load_requested(
	region_id: StringName,
	request_token: int,
) -> void:
	var descriptor: Dictionary = regions[region_id]
	var job := NucleusTerrainBuildJob.new()
	job.rows_per_step = 8

	var configure_error: Error = job.configure(
		descriptor["profile"],
		descriptor["material"],
		descriptor["position"],
	)

	if configure_error != OK:
		lifecycle.mark_request_failed(
			region_id,
			request_token,
			NucleusWorldStreamLifecycle.Operation.LOAD,
			configure_error,
		)
		return

	job.completed.connect(
		_on_region_patch_materialized.bind(region_id)
	)

	var submit_error: Error = materialization_binding.submit_job(
		region_id,
		request_token,
		NucleusWorldStreamLifecycle.Operation.LOAD,
		job,
	)

	if submit_error != OK:
		lifecycle.mark_request_failed(
			region_id,
			request_token,
			NucleusWorldStreamLifecycle.Operation.LOAD,
			submit_error,
		)
```

## 7. Attach before the request is acknowledged

The job emits its own `completed` signal before the queue emits its terminal
queue event.

Use that local completion to attach the patch:

```gdscript
func _on_region_patch_materialized(
	result: Variant,
	region_id: StringName,
) -> void:
	var payload: Dictionary = result
	var patch := payload["node"] as Node3D
	patch.name = String(region_id)
	region_root.add_child(patch)
```

Then the queue/binding acknowledges the lifecycle token.

The region is therefore `LOADED` only after its materialization job reached a
terminal completed state.

## 8. Unload remains game-owned

Unloading can be immediate when freeing one region is cheap:

```gdscript
func _on_unload_requested(
	region_id: StringName,
	request_token: int,
) -> void:
	var region := region_root.get_node_or_null(String(region_id))

	if region != null:
		region.queue_free()

	lifecycle.mark_unloaded(region_id, request_token)
```

If unloading itself contains expensive cleanup, create another incremental
`NucleusMaterializationJob` and submit it with `Operation.UNLOAD`.

## 9. Teleport while an island is building

Suppose:

```text
island_03
    LOADING

player teleports

desired = island_20
```

With stale cancellation enabled:

```text
desired_regions_changed
→ binding notices island_03 no longer desired
→ queue cancels the job
→ lifecycle.cancel_request()
→ island_03 returns to UNLOADED
```

The remaining height rows are never computed.

This is cheaper than finishing an obsolete island and immediately unloading it.

## 10. Re-desire during unload

The symmetric case also works:

```text
island_03 UNLOADING
player returns
island_03 desired again
```

The unload job can be cancelled and lifecycle returns to:

```text
LOADED
```

without manufacturing a failure/retry state.

## 11. Understand TerrainBuildJob steps

For heightmap collision the job batches:

```text
visual height rows
vertex/normal/UV rows
base index rows
LOD index rows
collision sampling rows
collision conversion rows
```

It then performs native finalization.

Tune:

```text
rows_per_step
queue.max_steps_per_frame
queue.frame_budget_usec
```

together.

A tiny `rows_per_step` lowers individual CPU bursts but increases total scheduling
overhead and time-to-ready.

## 12. Do not run gameplay physics at materialization cadence

The queue is for construction/loading work.

Once an actor/region is resident:

```text
physics
navigation steering
gameplay
```

continue at their normal required cadence.

Do not turn the materialization queue into a general update scheduler.

## 13. Combine with terrain quality

For a distant/prefetched island the game may choose a cheaper profile before job
creation:

```text
TerrainResolutionPolicy.REDUCED
TerrainMaterialProfile.REDUCED
collision disabled until needed
```

A nearby gameplay island can use:

```text
FULL visual resolution
normal gameplay collision
FULL/REDUCED material quality according to graphics preset
```

Nucleus exposes mechanisms; the game owns proximity/prefetch policy.

## 14. PBR package hygiene

Before materializing many regions, audit vendor texture sets:

```gdscript
var findings := NucleusTextureSetAudit.inspect_paths(package_paths)
```

Review duplicate runtime representations such as:

```text
NormalGL + NormalDX
Roughness + ARM
AO + ARM
unused displacement/height maps
```

Then run `NucleusTextureAudit` on the maps actually selected for runtime.

## 15. Profile the queue

Use:

```gdscript
queue.get_debug_snapshot()
```

to observe:

```text
pending_jobs
last_pump_steps
last_pump_usec
frame budget
```

Correlate this with `NucleusPerformanceSampler` and Godot's profiler.

The goal is stable frame pacing, not maximizing materialization throughput.

## 16. Final boundary

Keep this ownership:

```text
WorldStreamLifecycle
    what may load/unload now

MaterializationQueue
    how much incremental work may run this frame

TerrainBuildJob
    how one patch is constructed incrementally

Game
    what a region is, where it belongs, and which quality/content it needs
```

This is the reusable seam for Nautica-style island streaming without turning
Nucleus into a game-specific world manager.
