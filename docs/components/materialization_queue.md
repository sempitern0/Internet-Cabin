# Incremental Materialization Queue

Target engine: Godot 4.7.x.

`NucleusMaterializationQueue` budgets incremental **main-thread construction**.

It complements, but does not replace:

```text
NucleusResourceLoadQueue
NucleusUpdateScheduler
NucleusWorldStreamLifecycle
Godot ResourceLoader
```

## Public types

```text
NucleusMaterializationJob
NucleusMaterializationQueue
```

## Why this exists

Loading a Resource and materializing runtime content are different costs.

Examples:

```text
procedural terrain mesh construction
collision-grid generation
large scene setup
scatter population
game-owned streamed-region construction
```

A world-stream admission count can say:

```text
one region this frame
```

while that one region still consumes tens of milliseconds.

The materialization queue budgets **steps inside the work**.

## Job contract

A job moves through:

```text
PENDING
→ RUNNING
→ COMPLETED / FAILED / CANCELLED
```

Subclasses implement one bounded step:

```gdscript
func _step_job() -> Error:
	# Do a small, predictable chunk of work.
	return OK
```

Jobs can report:

```text
processed units
total units
progress ratio
terminal result
Error
```

Use:

```gdscript
set_progress(processed, total)
advance_progress(units)
complete(result)
fail(error)
```

## Queue budget

`NucleusMaterializationQueue` exposes:

```text
max_steps_per_frame
frame_budget_usec
process_automatically
```

The queue processes jobs round-robin.

A representative starting point:

```text
max_steps_per_frame = 4
frame_budget_usec = 2000
```

A zero microsecond budget disables the elapsed-time bound.

## Important budget boundary

The time budget is checked **between steps**.

The queue cannot preempt one already-running native call.

Therefore a job that performs:

```text
50 ms native operation
```

inside one `_step_job()` still causes a 50 ms hitch.

The correct design is:

```text
large O(n²) loops
    split into bounded batches

small native finalization
    one explicit step
```

and then profile the remaining native step.

## Cancellation

Cancellation is cooperative between steps.

```gdscript
queue.cancel_job(job)
```

moves a pending/running job to `CANCELLED`.

This is suitable for:

```text
teleport invalidated a streamed load
prefetch target changed
scene transition made warmup obsolete
```

It is not thread interruption.

## Threading boundary

The queue runs main-thread work by design.

Do not move arbitrary `Node`, scene-tree, physics, rendering or mutable Resource
work to worker threads just because it is expensive.

Worker-safe preprocessing can be introduced by the owning subsystem when Godot's
threading contract allows it, then handed back to a main-thread materialization
step.

## Resource loading relationship

A normal pipeline can be:

```text
ResourceLoadQueue
    loads source assets
        ↓
MaterializationQueue
    incrementally creates runtime representation
        ↓
game attaches/owns result
```

The queues remain independent because some materialization jobs require no
ResourceLoader work at all.

## Debugging

Use:

```gdscript
queue.get_debug_snapshot()
```

to inspect:

```text
pending_jobs
last_pump_steps
last_pump_usec
max_steps_per_frame
frame_budget_usec
```

Correlate these values with Godot's profiler and
`NucleusPerformanceSampler`.

The objective is stable frame pacing, not maximum construction throughput.
