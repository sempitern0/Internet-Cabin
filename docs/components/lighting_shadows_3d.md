# Native 3D Lighting and Shadow Quality

Target engine: Godot 4.7.x.

Nucleus does not replace Godot's 3D lighting renderer.

The lighting quality layer orchestrates native:

```text
DirectionalLight3D
OmniLight3D
SpotLight3D
AreaLight3D
Viewport positional shadow atlas
GeometryInstance3D shadow casting
```

The renderer remains authoritative for clustered lighting, light culling, shadow
maps, filtering, GI and final shading.

## Public types

Runtime:

```text
NucleusLightQualityProfile3D
NucleusLightQualityController3D
NucleusViewportShadowQualityProfile3D
NucleusViewportShadowQualityController3D
```

Development:

```text
NucleusLightingAudit3D
```

Existing related owners:

```text
NucleusGeometryQualityController3D
NucleusDaylightDriver3D
NucleusCelestialDriver3D
NucleusRenderAudit
```

## Complete shadow budget

A real-time shadow has three independent cost surfaces:

```text
caster
    GeometryInstance3D.cast_shadow

light
    Light3D shadow mode / distance / softness

viewport
    positional shadow atlas for Omni/Spot
```

Nucleus now exposes native quality policy at all three boundaries.

Do not create a custom shadow renderer merely to centralize these settings.

## NucleusLightQualityProfile3D

The profile exposes:

```text
MINIMAL
REDUCED
FULL
```

Full always restores authored state.

Reduced/Minimal may scale:

```text
shadow_blur
light_size
light_volumetric_fog_energy

authored local distance-fade begin
authored local fade length
authored local shadow cutoff

DirectionalLight3D shadow max distance
DirectionalLight3D light_angular_distance
```

They may also choose cheaper native modes:

```text
OmniLight3D
    cubemap
    → dual paraboloid

DirectionalLight3D
    4 splits
    → 2 splits
    → orthogonal
```

Projector textures can optionally be removed from lower tiers.

The profile does not alter:

```text
light energy
light color
transform
light range
light masks
shadow caster masks
bake mode
```

Those remain authored/game-owned semantics.

## Distance fade

Godot already provides native light LOD for:

```text
OmniLight3D
SpotLight3D
```

through:

```text
distance_fade_enabled
distance_fade_begin
distance_fade_length
distance_fade_shadow
```

Nucleus only scales these values when distance fade was already authored.

It does not invent scene-scale distances for a light that had no fade configured.

This is deliberate: meters/world scale and visual importance remain game policy.

A good authored relationship is commonly:

```text
shadow cutoff
    <
light fade end
```

because the shadow can disappear before the light itself.

`NucleusLightingAudit3D` reports local lights that lack distance fade and lights
whose shadow cutoff persists to the fade end.

## Shadow-enabled ownership

`NucleusLightQualityController3D.manage_shadow_enabled` is `false` by default.

This prevents two runtime owners from fighting over:

```text
Light3D.shadow_enabled
```

For example:

```text
NucleusDaylightDriver3D
    owns whether Sun/Moon currently need shadows

NucleusLightQualityController3D
    owns how expensive those shadows are
```

For a static lamp with no other shadow writer, enable:

```text
manage_shadow_enabled = true
```

to allow Minimal/Reduced tiers to disable shadows according to the profile.

One property should have one runtime owner.

## Soft shadows

Nucleus scales native:

```text
Light3D.light_size
DirectionalLight3D.light_angular_distance
Light3D.shadow_blur
```

rather than implementing a custom filtering path.

Directional angular-distance PCSS is a Forward+ feature.

Lower tiers can reduce or remove it while Full restores the authored value.

## Omni shadow mode

`OmniLight3D` supports:

```text
SHADOW_DUAL_PARABOLOID
SHADOW_CUBE
```

The default Nucleus profile uses dual paraboloid for Minimal and Reduced, while
Full restores the authored mode.

A game can preserve cubemap shadows in any tier by setting that tier's profile
mode to `Preserve`.

## Directional shadow mode

`DirectionalLight3D` supports:

```text
SHADOW_ORTHOGONAL
SHADOW_PARALLEL_2_SPLITS
SHADOW_PARALLEL_4_SPLITS
```

The default quality ladder is:

```text
Minimal
    orthogonal
    35% authored shadow distance
    no directional angular-distance softness
    no split blending

Reduced
    2 splits
    65% authored shadow distance
    50% authored angular distance
    preserve authored split blending

Full
    restore authored state
```

These defaults are a starting policy, not a performance guarantee.

Profile representative scenes on target hardware.

## Volumetric fog contribution

Each `Light3D` can contribute to volumetric fog.

The quality profile scales:

```text
light_volumetric_fog_energy
```

because large numbers of lights contributing to volumetric fog can be expensive.

The default Minimal tier removes this contribution.

The light's regular direct illumination is not changed.

## Projectors

Projector textures are presentation detail.

Minimal quality disables projectors by default; Reduced preserves them.

The controller restores the authored projector at Full quality.

Compatibility rendering does not support Light3D projector textures, so the
lighting audit reports renderer/feature mismatches.

## NucleusViewportShadowQualityProfile3D

Omni/Spot shadows share a Viewport positional shadow atlas.

The profile controls native:

```text
positional_shadow_atlas_size
positional_shadow_atlas_16_bits
quadrant 0 subdivision
quadrant 1 subdivision
quadrant 2 subdivision
quadrant 3 subdivision
```

Full restores the Viewport's authored values.

Default tiers:

```text
Reduced
    2048 atlas
    16-bit depth
    4 / 4 / 16 / 64 subdivisions

Minimal
    1024 atlas
    16-bit depth
    16 / 64 / 64 / 256 subdivisions
```

A game may set a tier's atlas size to:

```text
0
```

to intentionally disable all positional shadows for that Viewport.

This is appropriate only when the visual/readability tradeoff is acceptable.

## NucleusViewportShadowQualityController3D

Assign a Viewport explicitly or leave it unassigned to use the controller's
owning Viewport at runtime.

Use exactly one controller as the quality writer for a given Viewport.

Typical scene:

```text
World
├── LightingQuality
│   └── NucleusViewportShadowQualityController3D
├── Sun
│   ├── DirectionalLight3D
│   └── NucleusLightQualityController3D
├── Lighthouse
│   ├── SpotLight3D
│   └── NucleusLightQualityController3D
└── VillageLamp
    ├── OmniLight3D
    └── NucleusLightQualityController3D
```

## Renderer differences

Nucleus does not normalize renderer capabilities.

The lighting audit identifies the active rendering method through Godot and
reports obvious mismatches.

Important examples:

```text
Forward+
    clustered lighting
    directional PCSS
    projectors
    AreaLight3D shadows

Mobile
    limited local lights per mesh
    local soft shadows/projectors
    no directional PCSS

Compatibility
    limited local lights per mesh
    no projectors
    no directional PCSS
    no AreaLight3D shadows
```

Do not use a Nucleus profile as proof that one scene fits every renderer.

## NucleusLightingAudit3D

Run:

```gdscript
var findings: Array[NucleusPerformanceDiagnostic] = (
	NucleusLightingAudit3D.inspect(
		world_root,
		get_viewport(),
	)
)
```

The audit can report:

```text
many shadowed local lights
local lights without native distance fade
local shadows that persist until light fade ends
many cubemap Omni shadows
AreaLight3D pressure
many soft-shadow lights
many projector lights
high-quality directional shadow features
renderer/feature mismatch
disabled positional atlas while local shadows are requested
```

The audit does not mutate nodes.

A finding means:

```text
measure this
```

not:

```text
this content is wrong
```

For compact development output:

```gdscript
NucleusLog.debug_data(
	"Lighting",
	NucleusLightingAudit3D.snapshot(
		world_root,
		get_viewport(),
	),
	&"rendering",
	{"multiline": true},
)
```

## Lit-inspired boundary

The reviewed Lit addon demonstrates valuable production ideas:

```text
cache stable light metadata
avoid unnecessary shadow work
make quality explicit
test activity/quality behavior
warm expensive presentation before first visible use
```

For 3D Nucleus keeps these ideas at the policy/tooling layer.

It does not port Lit's custom:

```text
2D light registry
screen-tile light buffers
custom receiver shaders
world SDF
shadow raymarching
cookie atlas
```

because Godot's 3D renderer already owns those responsibilities.

## Integration with celestial/daylight

Preferred Sun/Moon composition:

```text
WorldClock
    ↓
CelestialDriver3D
    ↓
DaylightDriver3D
    ↓
DirectionalLight3D
    ↓
LightQualityController3D
```

Ownership:

```text
CelestialDriver
    celestial position/state

DaylightDriver
    light color/energy
    optional shadow-enabled gate

LightQualityController
    shadow mode
    shadow distance
    softness
    fog contribution
```

Do not enable `manage_shadow_enabled` on Sun/Moon when
`NucleusDaylightDriver3D` already owns that property.

## Integration with geometry quality

Lighting quality controls the light side.

`NucleusGeometryQualityController3D` controls the caster side.

For lower tiers a project can compose:

```text
Geometry MINIMAL
    fewer/distant casters

Light MINIMAL
    cheaper shadow algorithms/ranges

Viewport MINIMAL
    smaller positional atlas
```

This reduces shadow cost without changing gameplay simulation.

## Bake mode

`Light3D.light_bake_mode` is intentionally not a runtime quality knob here.

Changing between static/dynamic bake policy requires authored/baked data and is
not equivalent to changing a graphics preset.

Use:

```text
LightmapGI
VoxelGI
SDFGI
```

according to the product's renderer/content requirements.

Nucleus may audit bake policy in a future iteration if a real consumer exposes
repeated friction.

## Performance validation

Measure separately:

```text
GPU frame time
CPU frame/setup time
draw calls
shadow draw calls
VRAM
visual stability during camera movement
```

Validate:

```text
Full
Reduced
Minimal
```

as actual shipping modes.

The correct low-end target is not "everything disabled"; it is the cheapest
presentation that still preserves scene readability and product quality.
