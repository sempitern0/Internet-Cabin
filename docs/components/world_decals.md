# World Decals Contract

`NucleusSmartDecal3D` is a scene-owned presentation helper built on Godot's native
`Decal`. It solves reusable placement, orientation, variation, lifetime and pool
release; it does not own impact gameplay or decal art selection.

## Placement

```gdscript
var error := decal.place_on_surface(hit_position, hit_normal)
```

Local `+Y` is aligned to the outward surface normal so the native projector points
into the receiving surface. Optional tangent hints control planar roll/orientation.

Random visible-size variation changes `Decal.size.x/z` only. `size.y` remains
projection depth and should be authored deliberately.

## Surface semantics

When content depends on material identity:

```text
Godot collision
→ NucleusSurfaceResolver3D
→ game selects decal content
→ NucleusSmartDecal3D places it
```

SmartDecal does not infer textures from physics/material names.

## Native controls and limitations

Projection depth, normal fade, upper/lower fade and cull masks remain native Decal
properties. Nucleus does not duplicate them.

Godot decal renderer/platform limits remain applicable; density/lifetime/pooling
should be conservative on tighter targets.

## Lifetime and pooling

Timed decals can fade alpha/emission and emit expiration. With a
`NucleusPoolable`, expiration may release the instance back to its local pool;
otherwise project configuration decides whether the scene is freed or hidden.

There is no global decal manager or global decal budget in this component.
