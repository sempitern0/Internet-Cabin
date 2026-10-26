# Measuring input reception-to-consumption intervals

## Reuse the performance profiler

`NucleusPerformanceSectionProfiler` already supports explicit monotonic
microsecond timestamps (`begin_section`, `end_section`), configurable budgets,
statistics, and integration with `NucleusPerformanceSampler`. A second input
latency sampler would duplicate that owner.

For a **game-owned** controller that receives an `InputEvent` then consumes
its buffered intent in a later processing phase, keep the token alongside that
intent:

```gdscript
@export var profiler: NucleusPerformanceSectionProfiler
var pending_token: int = 0

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and pending_token == 0:
        if profiler != null:
            pending_token = profiler.begin_section(&"input.received_to_consumed")
    # Forward the input through the project's existing Nucleus input owner.

func _physics_process(_delta: float) -> void:
    # After the existing movement/action owner has actually consumed the intent:
    if pending_token != 0 and profiler != null:
        profiler.end_section(pending_token)
        pending_token = 0
```

This is instrumentation *around* the owner's real processing, not a substitute
for `NucleusInput`, `NucleusMotionInput`, `InputMap`, or the physics controller.
Adapt the action and phase to the consuming game; the sample is meaningful
only when the token corresponds to an intent that was actually handled.

## What this measures — and what it does not

- Measured: elapsed **wall-clock time from the `_input` callback to the chosen
  consumption boundary** using monotonic engine ticks.
- Not measured: USB/Bluetooth hardware latency, OS event queueing before
  `_input`, physics settling, display scan-out, compositor lag, or photons.
- The chosen phase and buffering policy affect results. Processing-time
  statistics do not automatically characterize total player-perceived latency.
- Use the existing performance sampler for frame pacing and section costs;
  use external high-speed-camera or instrumented hardware measurements for
  device-to-photon latency.

Call `end_section()` or deliberately discard tokens when a scene is cancelled,
input is rejected, or authority changes. The profiler is opt-in and can be
restricted to debug builds. Never make gameplay correctness depend on metrics.
