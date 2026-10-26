# World Buoyancy Contract

`NucleusBuoyancy3D` provides bounded multi-point buoyancy for native
`RigidBody3D` objects against a `NucleusSurfaceSampler3D`. There is no fluid
manager, custom rigid-body class or replacement physics engine.

## Ownership

```text
project-owned analytical surface
        ↓
NucleusSurfaceSampler3D
    point + normal + surface velocity
        ↓
NucleusBuoyancy3D
    lift + damping + horizontal drag
        ↓
native RigidBody3D / Godot physics
```

The game owns water equations, visuals, wakes, vehicle handling, swimming,
weather and authored hull shape/tuning.

## Displacement model

Buoyancy samples authored local points and treats each as a vertical displacement
column. Total `displacement_volume` is divided across points. For ordinary Godot
units, approximate maximum supported mass is:

```text
fluid_density × displacement_volume
```

Mass remains the native body mass; Nucleus never edits it to make an object
float.

`column_height` defines the dry→submerged transition depth. The model is a stable
game-physics approximation, not mesh-volume clipping or CFD.

## Damping and drag

Vertical damping is based on point velocity relative to the sampled moving
surface and is bounded to avoid unstable single-frame corrections. Horizontal
`linear_drag` drives wet-point X/Z velocity toward surface velocity.
`angular_drag` opposes angular velocity according to wet fraction.

Lift can be capped with `maximum_lift_acceleration` for recovery stability.

## Hot-path behavior

The component reuses one `NucleusSurfaceSample3D` through `sample_into()` instead
of allocating one result per point per physics tick. Failed samples treat the
point as dry for that tick.

Keep the body at unit scale and author collision dimensions, sample points,
column height and displacement volume coherently in metres.

## Sleeping / authority

Nucleus does not silently rewrite `can_sleep`. A game may disable sleep for
continually animated surfaces when required.

With multiplayer active and `require_multiplayer_authority = true`, only the
body's authority applies buoyancy forces. Replicate resolved body state rather
than running two authoritative physical simulations.

## Diagnostics and performance

Useful queries include wet fraction, sampled point count and displacement
capacity. Per physics tick cost scales primarily with sample-point count and the
cost of the analytical surface sampler, so begin with a small well-spaced point
set and profile representative hardware.
