# World Feedback History Contract

This subsystem provides bounded world-space history for transient visual marks.
It is suitable for wake coverage, footprints, tire tracks, flattened vegetation,
surface wetness, ripples or similar presentation where marks must remain at their
world position while a bounded texture window moves.

Public types:

```text
NucleusWorldStamp3D
NucleusWorldStampBuffer3D
NucleusWorldStampViewport3D
```

There is no global feedback manager and the buffer is not gameplay authority.

## Buffer model

A stamp stores world position, dimensions, rotation, strength, lifetime, drift,
growth and optional metadata. The buffer owns bounded stamp/emitter capacities,
logical time, a world-space center and coverage size.

Changing the buffer center moves the **projection window**, not stored marks:

```text
move window ≠ move history
```

`emit_motion()` provides distance-based trail emission with per-call and emitter
limits, preventing density from scaling directly with FPS. Teleport-sized jumps
reset emitter history rather than drawing a stripe across the window.

## Optional viewport renderer

`NucleusWorldStampViewport3D` renders active marks into one transparent
SubViewport texture. It uses update-on-demand behavior and performs no GPU→CPU
readback.

The texture is a scalar coverage/history field. The game-owned material decides
whether that field becomes foam, compressed snow, mud, ripples or another visual
language.

If no stamp texture is assigned, the runtime radial gradient is a development
fallback rather than art direction.

## Quality / multiplayer / persistence

Texture resolution, coverage and stamp capacity are independent project quality
choices. Profile the receiving material and target hardware rather than treating
one resolution tier as universal.

History is normally client presentation in multiplayer. Replicate authoritative
events/state, not render-target pixels. If tracks have gameplay meaning, store a
separate authoritative semantic model and let this buffer mirror it visually.

Transient history is not persisted by default. Durable marks should be rebuilt
from persistent semantic world state instead of serializing the viewport texture.
