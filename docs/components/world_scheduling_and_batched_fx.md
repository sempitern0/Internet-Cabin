# Deterministic Scheduling and Batched Surface FX

This contract covers two reusable patterns proven by world/environment workloads:

```text
NucleusDeterministicSchedule
NucleusTransientSurfaceBatch3D
```

They are intentionally independent. One is pure deterministic time policy; the
other is bounded presentation.

## Deterministic schedule

`NucleusDeterministicSchedule` partitions absolute simulation time into fixed
segments.

It owns only:

```text
base seed
optional seed salt
segment duration
transition duration
stable segment seed derivation
```

It does not own weather, encounters, shops, music, populations or any other game
state.

Example using `NucleusWorldClock`:

```gdscript
var total := clock.get_total_game_seconds()
var current := schedule.get_segment_index(total)
var previous := schedule.get_previous_segment_index(total)
var blend := schedule.get_transition_alpha(total)

var previous_rng := schedule.create_rng(previous)
var current_rng := schedule.create_rng(current)
```

The game derives semantic states from those RNG streams and blends them according
to its own rules.

### Transition semantics

At a segment boundary the blend is `0`. During
`transition_duration_seconds`, it moves smoothly from previous-segment state to
current-segment state, then remains at `1` until the next boundary.

Set transition duration to zero for hard segment changes.

### Deterministic streams

`get_segment_seed(segment_index, stream)` lets one segment derive independent
stable streams, for example:

```text
stream 0 -> weather state
stream 1 -> ambient population
stream 2 -> encounter seed
```

The seed derivation algorithm has its own version constant. Changing it in a
future Nucleus release requires explicit compatibility consideration because it
would change generated schedules.

For save/load, normally persist the authoritative simulation time and the
game/world seed. Persist generated semantic schedule state as well when a game
must survive changes to its own generation algorithm.

## Batched transient surface FX

`NucleusTransientSurfaceBatch3D` renders many short-lived surface-aligned effects
through one bounded `MultiMeshInstance3D`.

Typical uses:

```text
rain-ground impacts
small splashes
sparks
dust contacts
temporary glints
short-lived contact marks
```

Call:

```gdscript
batch.emit_surface(
	hit_position,
	hit_normal,
	Vector2(0.2, 0.2),
	0.6,
	Color.WHITE,
	Vector2(1.5, 1.5),
)
```

The batch stores world-space transform, lifetime, per-instance color and growth.
Expired entries are removed without creating/freeing a Node per impact. Once
capacity is full, new effects recycle bounded storage.

The internal MultiMesh is top-level and uses world-space transforms so existing
effects stay where they were emitted even if the batch owner follows a player.

### Material contract

Nucleus supplies a neutral `QuadMesh` fallback when no mesh is assigned.

For authored presentation, assign a project material/shader. A shader that wants
the built-in fade/color information must consume MultiMesh per-instance color.
With `BaseMaterial3D`, enable `vertex_color_use_as_albedo` when that is the
intended color path.

The batch does not own textures, blending style, decals, surface classification
or effect semantics.

### Compose with existing FX tools

A typical precipitation flow is:

```text
NucleusLocalFxVolume3D
        ↓ intensity / quality
NucleusFxSpawnBudget
        ↓ bounded event count
project physics query
        ↓
NucleusSurfaceResolver3D (optional semantic classification)
        ↓
NucleusTransientSurfaceBatch3D
```

The batch deliberately does **not** cast rays itself. The game may need a ray,
shape query, analytical surface sampler or no query at all.

## Performance

The batch replaces node-per-impact churn and many individual draw calls with one
bounded MultiMesh. CPU still updates active instance transforms/colors, so keep
capacity appropriate for the actual visual need.

Automatic bounds are derived from active effects. Disable `auto_update_bounds`
only when the project explicitly owns a stable custom AABB policy.
