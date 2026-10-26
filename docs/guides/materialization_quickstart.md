# Incremental Materialization Quickstart

Use this when a loaded/generated world object is too expensive to create in one
frame.

Technical contracts:

```text
docs/components/materialization_queue.md
docs/components/world_stream_materialization.md
docs/modules/terrain_materialization.md
```

Tutorial:

```text
docs/guides/tutorials/world_stream_materialization_budgeting.md
```

## 1. Add a queue

```text
NucleusMaterializationQueue
```

Start with:

```text
max_steps_per_frame = 4
frame_budget_usec = 2000
```

Then profile.

## 2. Create bounded jobs

Subclass:

```text
NucleusMaterializationJob
```

and keep one `_step_job()` small.

For terrain use the ready-made:

```text
NucleusTerrainBuildJob
```

## 3. Keep game semantics outside the queue

The queue does not know:

```text
distance
visibility
region priority
biome
persistence
network ownership
```

Those remain in the consuming game.

## 4. Use the stream binding when appropriate

For region streaming compose:

```text
WorldStreamLifecycle
MaterializationQueue
WorldStreamMaterializationBinding
```

The binding acknowledges request tokens and can cancel stale jobs after desire
changes.

## 5. Measure

Watch:

```text
queue last_pump_usec
pending jobs
frame time
time-to-ready
```

Tune job granularity and queue budget together.
