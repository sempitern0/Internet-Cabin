# Tutorial: Scattered Vegetation Without a Custom Renderer

Create a basic Godot scene:

```text
World
├── Surface : NucleusPlaneSurfaceSampler3D
├── MaterializationQueue : NucleusMaterializationQueue
└── GrassRegion : NucleusScatterRegion3D
```

Make a `NucleusScatterVariant3D` with a low-poly grass clump mesh and disable
shadows for that species. Assign it to `NucleusScatterProfile3D.variants`.
Use a 2m grid spacing and a deterministic seed. Assign profile and surface to
the region, with size `Vector2(32, 32)`.

Invoke `start_build(materialization_queue)` when loading the region. The
existing materialization queue performs bounded main-thread steps; the region
creates at most `batches_per_frame` new MultiMesh batches per frame afterward.

Change the seed and build again to see a different arrangement. Return to the
original seed to reproduce the same world-cell positions. Place two regions
beside one another (the second at world X=32) and enable `minimum_separation`
to see seam-safe placement.

Create a `NucleusScatterDensityVolume3D` near a road, set its multiplier to
zero, and reference it from both affected regions. Rebuild to remove the
vegetation there without touching terrain meshes or physics colliders.

Finally, test with a terrain surface sampler, different slopes and distances,
then measure draw calls, frame times and GPU pressure. The scene owns its
terrain, assets, and biome rules; Nucleus only implements the placement and
native rendering mechanics.
