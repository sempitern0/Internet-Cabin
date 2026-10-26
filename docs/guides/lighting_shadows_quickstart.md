# 3D Lighting and Shadows Quickstart

Use this guide to add scalable native Godot lighting without introducing a
custom renderer or a global light manager.

Technical contract:

```text
docs/components/lighting_shadows_3d.md
docs/components/rendering_quality.md
```

Hands-on tutorial:

```text
docs/guides/tutorials/lighting_shadows_3d.md
```

## 1. Author normal Godot lights

Use native:

```text
DirectionalLight3D
OmniLight3D
SpotLight3D
AreaLight3D
```

Set their artistic baseline first:

```text
color
energy
range
shadow bias
masks
projectors
softness
```

Nucleus Full quality restores this authored state.

## 2. Author distance fade on local lights

For Omni/Spot lights that do not need to exist at arbitrary camera distances:

```text
distance_fade_enabled = true
distance_fade_begin = project-appropriate distance
distance_fade_length = smooth transition length
distance_fade_shadow = shorter than light fade end
```

Nucleus scales these authored distances in lower quality tiers.

It does not invent scene-scale distances automatically.

## 3. Add per-light quality

Create:

```text
NucleusLightQualityProfile3D
```

Then parent a controller beneath the light:

```text
Lamp : OmniLight3D
└── Quality : NucleusLightQualityController3D
```

The controller auto-resolves its Light3D parent.

Typical preset mapping:

```text
Low
    MINIMAL

Medium
    REDUCED

High / Ultra
    FULL
```

## 4. Decide shadow-enabled ownership

For an ordinary lamp with no other runtime shadow writer:

```text
manage_shadow_enabled = true
```

For Sun/Moon driven by:

```text
NucleusDaylightDriver3D
```

leave:

```text
manage_shadow_enabled = false
```

The quality controller will still reduce shadow mode/range/softness without
fighting the daylight gate.

## 5. Add Viewport shadow quality

Create:

```text
NucleusViewportShadowQualityProfile3D
NucleusViewportShadowQualityController3D
```

If target Viewport is unassigned, the controller uses its owning Viewport.

This controls the shared Omni/Spot shadow atlas.

Use one quality controller per Viewport.

## 6. Compose caster quality

For expensive distant geometry, use:

```text
NucleusGeometryQualityController3D
```

so a lower preset can reduce:

```text
shadow casters
light shadow cost
shadow atlas cost
```

together.

## 7. Audit

Run during development:

```gdscript
var findings: Array[NucleusPerformanceDiagnostic] = (
	NucleusLightingAudit3D.inspect(
		world_root,
		get_viewport(),
	)
)
```

Review:

```text
shadowed local light count
distance fade
shadow cutoff
Omni cubemap use
AreaLight3D
soft shadows
projectors
directional splits/range/PCSS
renderer compatibility
```

## 8. Profile the real scene

A good starting policy is:

```text
Full
    authored production lighting

Reduced
    2-split sun
    shorter directional shadows
    dual-paraboloid Omni shadows
    reduced softness/fog
    2048 positional atlas

Minimal
    orthogonal sun
    much shorter directional shadows
    hard/cheap local shadows
    no decorative projectors/fog contribution
    1024 positional atlas
```

Tune these values against the game's actual camera scale, art and supported
hardware.
