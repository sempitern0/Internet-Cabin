# Incremental Terrain Materialization

`NucleusTerrainBuildJob` incrementally builds **one heightfield terrain patch**.

It exists for cases where one patch is too expensive to construct in a single
frame, even when world-stream admission is already limited.

## Relationship to existing terrain APIs

Keep using:

```text
NucleusTerrainGenerator3D.generate_terrain()
```

for editor generation, loading screens and modest finite terrain.

Keep using:

```text
generate_terrain_async()
```

when spreading multiple **whole patch** builds is sufficient.

Use:

```text
NucleusTerrainBuildJob
+
NucleusMaterializationQueue
```

when work **inside one patch** must be divided.

## Incremental stages

The job row-batches the large loops:

```text
height sampling
vertex / normal / UV generation
base index generation
LOD index generation
heightmap collision sampling
heightmap collision conversion
```

Then it performs explicit native finalization steps:

```text
ArrayMesh.add_surface_from_arrays()
HeightMapShape3D data assignment
TRIMESH shape creation when explicitly selected
Node assembly
```

Native finalization cannot be preempted once entered.

## Configure

```gdscript
var job := NucleusTerrainBuildJob.new()
job.rows_per_step = 8

var error: Error = job.configure(
	profile,
	material,
	patch_position,
	1.0,
	false,
	0,
	true,
	true,
)
```

Arguments preserve the regular terrain patch semantics:

```text
profile
material
position
scale
force_island
resolution override
collision
LOD
optional material overlay
```

## Enqueue

```gdscript
materialization_queue.enqueue(job)
```

A completed result contains:

```text
error = OK
node = unattached Node3D terrain patch
mesh = ArrayMesh
```

The game owns attachment:

```gdscript
job.completed.connect(
	func(result: Variant) -> void:
		var payload: Dictionary = result
		var patch := payload["node"] as Node3D
		region_root.add_child(patch)
)
```

The job does not assume a world hierarchy.

## `rows_per_step`

Lower values:

```text
smaller CPU burst per job step
more scheduler overhead
longer time-to-ready
```

Higher values:

```text
faster completion
larger individual CPU bursts
```

Profile representative terrain sizes.

## Collision

`HEIGHTMAP` is the preferred streamed-terrain collision mode because sampling and
height conversion can be batched.

`TRIMESH` remains supported but:

```text
mesh.create_trimesh_shape()
```

is one native finalization step and may be expensive.

Use `DISABLED` for distant visual-only terrain where gameplay allows it.

## Streaming composition

For arbitrary islands/regions:

```text
WorldStreamLifecycle
→ game creates TerrainBuildJob
→ WorldStreamMaterializationBinding
→ MaterializationQueue
→ game attaches patch
```

`NucleusTerrainStreamer3D` remains the smaller specialized solution for linear
moving windows.

Do not replace it merely for abstraction.

## Parity contract

The incremental job follows the same height sampling, normal calculation,
indices, LOD distance semantics and heightmap collision model as the synchronous
terrain builder.

Headless tests compare incremental visual topology against the existing
synchronous patch path to catch future drift.

## Low-end composition

Before job creation, the game can apply:

```text
NucleusTerrainResolutionPolicy
NucleusTerrainMaterialProfile quality
collision policy
```

according to its own proximity/graphics/prefetch rules.

A materialization job is an execution mechanism, not a quality heuristic.
