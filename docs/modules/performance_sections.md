# Optional Performance Section Profiling

Target: Nucleus on Godot 4.7.2-stable.

`NucleusPerformanceSectionProfiler` is an opt-in, scene-owned instrument for
**authored synchronous sections** and sampler-window frame hitches. It extends
`NucleusPerformanceSampler`; it is not another engine profiler, Autoload, or
independent per-frame performance collector.

> [!IMPORTANT]
> **Instrument only known expensive sections.** Measured wall-clock
> duration is not a CPU-only profiler or GPU timing measurement.

## Ownership and limits

- Native Godot Profiler still owns deep CPU/script call profiling.
- NucleusPerformanceSampler still owns frame-interval sampling and reports.
- The section profiler measures only code where the game explicitly calls
  `begin_section()` and `end_section()` using `Time.get_ticks_usec()`.
- Measurements are **elapsed wall time**, not thread-exclusive CPU time. They
  include waits, blocking calls and scheduling; do not label them CPU usage.
- Crossing `await` measures total elapsed time rather than synchronous code.
  Prefer starting/ending within a single synchronous operation.
- No automatic instrumentation or instrumentation of other scripts occurs.

## Setup

Add a `NucleusPerformanceSectionProfiler` Node to the development session.
Point its exported `sampler` reference at the existing scene-owned
`NucleusPerformanceSampler`. No new Autoload is needed. If the sampler changes
with a session, use `bind_sampler(next_sampler)` to safely detach the old one.

The optional sampler may be absent: sections still accumulate local statistics
and hitch events, but no snapshot metrics/traces are sent elsewhere.

**Never skip gameplay** when the profiling token is zero (disabled or at
capacity). The correct usage is:

```gdscript
var token: int = section_profiler.begin_section(&"streaming/spawn")
spawn_visible_region()
if token != 0:
    section_profiler.end_section(token)
```

`end_section()` returns elapsed milliseconds or `-1.0` if its token is
invalid/stale or the clock moved backwards. Each token is single-use.
Sections with the same name can overlap or nest and still measure independently.

## Explicit budgets

`default_section_budget_ms = 0.0` disables section warnings by default.
Assign a per-label threshold when you have a workload-specific budget:

```gdscript
section_profiler.set_section_budget(&"network/interest_update", 2.5)
```

On an over-budget completion it emits `section_over_budget` and stores a bounded
hitch event. With a sampler attached, `trace_section_hitches = true` adds an
`section_over_budget` marker with the label and duration to the sampler's
existing `traces` / JSON report. Normal section completions emit
`section_measured`, but do not produce a trace per call.

`get_section_statistics(label)` returns a detached dictionary containing:

```text
samples, last_ms, total_ms, minimum_ms, maximum_ms,
average_ms, over_budget_count
```

`get_all_section_statistics()` returns a detached map keyed by section name.
`clear_capture()` invalidates all outstanding tokens and removes measured
statistics/hitch events, but preserves configured per-label budgets.

## Integration with existing performance reports

If `publish_section_probes` is enabled (default), the profiler registers one
numeric sampler probe for each completed, tracked label:

```text
section/<label>/last_ms
```

For example, the value of `section/network/interest_update/last_ms` appears in
regular `NucleusPerformanceSnapshot.values`, their serialized report `samples`,
and can be queried via `sampler.get_metric_statistics(id)`.

These are **last observed completions at the moment of sampling**, not a
continuous time series of every invocation; long gaps may leave a stale last
value until the next completion. The profiler unregisters only its own probes
on scene exit, `clear_capture()` or `bind_sampler()` changes. Existing sampler
probes, summary monitors and reports are not replaced.

The sampler's generic `metric_summary` covers built-in metric IDs. For section
metrics inspect the report's `samples`, call `get_metric_statistics()` with the
section ID, or use `get_all_section_statistics()` for invocation aggregates.

## Frame hitches

When bound to a sampler, the profiler listens for `snapshot_sampled` and reads
`FRAME_INTERVAL_MAX_MS` if present. If the **largest interval in that sampler
window** reaches `frame_hitch_threshold_ms` (default 25 ms), it emits
`frame_hitch_detected`, stores a bounded event, and optionally marks
`frame_interval_hitch` in the sampler's trace buffer.

This is window-level attribution: the sampler does not report which individual
frame produced that maximum, and the trace timestamp is when the window was
sampled. Do not assert frame-exact correlation or CPU causality based on this
signal. Disable it with `frame_hitch_threshold_ms = 0.0`.

## Bounded cost and safe lifecycle

The component performs no `_process`/`_physics_process` polling. Work happens
only when called or when the sampler already publishes a snapshot. It has three
separate caps:

- `max_active_sections` (default 128) bounds in-flight timestamps.
- `max_tracked_labels` (default 64) bounds distinct labels/statistics/probes.
- `max_label_length` (default 96 characters) limits label memory/metric IDs.
- `hitch_history_capacity` (default 128) bounds recorded hitch events.

`begin_section` returns `0` at capacity. `debug_build_only` defaults to `true`,
matching the sampler's production-safe default. Disable all measurement with
`enabled = false`. Dynamic string labels such as unique entity IDs can exhaust
the cap; use stable subsystem/action names instead. Authored per-label budget
entries are also bounded by `max_tracked_labels`.

`get_hitch_history()` returns a detached event list. This is not an analytics
backend and never automatically uploads performance data.

## Testing

Registered headless regression test:

```text
tests/headless/performance_sections_test.gd
```

Run the normal project-scene test runner:

```bash
python3 scripts/ci/static_checks.py
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
```

For actual performance comparisons, profile a repeatable representative workload
in a standalone debug export and use Godot's native Profiler as well. Debug and
instrumentation overhead can materially affect measured timing.

## Use cases

| Scenario | Instrument | What to verify |
| --- | --- | --- |
| Network interest reconciliation occasionally stalls | Measure one reconcile section | Concurrent peer count and actual network profiler |
| Scene streaming produces intermittent hitches | Time materialization/physics activation | CPU profiler, frame interval and GPU first-use |
| Large inventory sort is slow | Time the full sort action | Data set size and UI redraw cost |

Prefer native Godot CPU/GPU specialist tools when deep per-function or GPU
profiling is required. Instrument only a small set of important logical work
sections so the profiler does not become the bottleneck.
