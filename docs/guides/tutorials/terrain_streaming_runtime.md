# Tutorial: Run Linear Terrain Streaming at Runtime

This tutorial demonstrates `NucleusTerrainStreamer3D` as a **moving linear chunk
window**. It is not a general infinite-world manager.

Runnable reference scene:

```text
res://examples/terrain/terrain_streaming.tscn
```

## Ownership

```text
World
├── Player
└── TerrainStream : NucleusTerrainStreamer3D
```

Assign the tracked node and streaming axis. The streamer remains scene-owned.

## Start conservatively

A representative first test can use a modest patch resolution, lower collision
resolution, a small LOD count, a few chunks ahead/behind and one new chunk per
update. If traversal outruns generation, reduce per-patch work or increase lead
distance before simply increasing build admission per update.

## Lifecycle and continuity

The public API exposes loaded/unloaded chunk events plus center/loaded/pending
queries for game coordination and development UI. Gameplay should not reach into
private chunk dictionaries.

Adjacent patches sample the same world-position noise field; `patch_gap = 0`
keeps contiguous ground.

## Teleports

A large center change removes chunks outside the new window and queues missing
chunks nearest-first. If a destination must be fully ready before arrival, the
game owns the loading/teleport presentation rather than expecting the streamer to
freeze scene flow automatically.

## When not to use it

Choose another world ownership model for omnidirectional open worlds, clipmaps,
persistent per-chunk edits, large streamed ecosystems or a bounded world that is
simpler to materialize as a finite layout.

## Validate

Run the example and verify the loaded count stays bounded, pending work settles,
chunks advance with the tracked target and contiguous patches do not show seams.
