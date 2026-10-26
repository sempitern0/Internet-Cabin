# Rendering Quality Quickstart

Use this guide for texture/material hygiene and reusable low-end 3D presentation
tiers.

Canonical contracts:

```text
docs/components/rendering_quality.md
docs/components/lighting_shadows_3d.md
```

Hands-on:

```text
docs/guides/tutorials/material_texture_optimization_3d.md
docs/guides/tutorials/lighting_shadows_3d.md
```

## 1. Audit textures without mutating them

Create a `NucleusTextureBudgetProfile` appropriate for the project.

Example development thresholds:

```text
review at 2048
strong review at 4096
```

Then inspect a relevant directory or explicit path list.

Review diagnostics for:

```text
dimensions
mipmaps
compression
normal-map import intent
```

Do not bulk-reimport solely because an audit fired.

## 2. Share materials where possible

Before duplicating a `ShaderMaterial` to change one number/color, ask whether the
shader can use an `instance uniform`.

Use:

```text
NucleusMaterialInstanceBinding3D
```

for runtime values such as tint, wetness, damage, wind phase, dissolve, or other
scalar/vector presentation data.

## 3. Create material quality tiers

Create:

```text
NucleusMaterialQualityProfile3D
```

Typical policy:

```text
Full
    null → keep authored material

Reduced
    reduced-cost material

Minimal
    cheapest acceptable material
```

Add a `NucleusMaterialQualityController3D` to the
`GeometryInstance3D` that should switch tier.

## 4. Add native geometry quality

Create:

```text
NucleusGeometryQualityProfile3D
```

Tune:

```text
LOD bias scales
optional visibility caps
shadow-caster disabling
```

Use a `NucleusGeometryQualityController3D` on the same or another
`GeometryInstance3D`.

## 5. Add native light quality

Author ordinary Godot:

```text
DirectionalLight3D
OmniLight3D
SpotLight3D
AreaLight3D
```

Then add:

```text
NucleusLightQualityProfile3D
NucleusLightQualityController3D
```

to lights that should scale with the product graphics preset.

Prefer native distance fade on Omni/Spot lights before inventing custom camera
distance logic.

## 6. Add Viewport shadow quality

Create:

```text
NucleusViewportShadowQualityProfile3D
NucleusViewportShadowQualityController3D
```

to control the shared positional shadow atlas.

Use one controller per Viewport.

## 7. Respect shadow ownership

For Sun/Moon driven by:

```text
NucleusDaylightDriver3D
```

leave:

```text
manage_shadow_enabled = false
```

For an ordinary lamp with no other runtime shadow writer, it may be enabled.

## 8. Audit scene rendering and lighting

Run:

```gdscript
var render_findings: Array[NucleusPerformanceDiagnostic] = (
	NucleusRenderAudit.inspect(root)
)
var light_findings: Array[NucleusPerformanceDiagnostic] = (
	NucleusLightingAudit3D.inspect(
		root,
		get_viewport(),
	)
)
```

Measure before restructuring scenes.

## 9. Map product presets

Nucleus does not introduce another global graphics manager.

A game can map its existing settings:

```text
Low
    Material MINIMAL
    Geometry MINIMAL
    Light MINIMAL
    Viewport shadows MINIMAL

Medium
    Material REDUCED
    Geometry REDUCED
    Light REDUCED
    Viewport shadows REDUCED

High / Ultra
    Material FULL
    Geometry FULL
    Light FULL
    Viewport shadows FULL
```

Different actor/light categories may use different mappings.

## 10. Validate low quality as a real shipping mode

Test Low on representative weak hardware.

Check:

```text
material readability
LOD transitions
light fade transitions
shadow cutoff
shadow resolution
sun shadow distance
visibility popping
texture quality
VRAM
draw calls
GPU time
CPU frame/setup time
```

The objective is not merely "lower settings". It is a version of the game that
remains readable, responsive and intentionally art-directed.
