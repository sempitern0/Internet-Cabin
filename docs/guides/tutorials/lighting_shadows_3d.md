# Tutorial: Scalable Native 3D Lighting and Shadows

This tutorial creates a production-oriented lighting stack using only Godot's
native Light3D/Viewport renderer plus Nucleus quality policy.

## 1. Scene

Create:

```text
World
├── Sun : DirectionalLight3D
│   └── SunQuality : NucleusLightQualityController3D
├── Lighthouse : SpotLight3D
│   └── LighthouseQuality : NucleusLightQualityController3D
├── VillageLamp : OmniLight3D
│   └── LampQuality : NucleusLightQualityController3D
└── ShadowQuality : NucleusViewportShadowQualityController3D
```

Create one:

```text
NucleusLightQualityProfile3D
```

and assign it to all three light controllers.

Create one:

```text
NucleusViewportShadowQualityProfile3D
```

and assign it to `ShadowQuality`.

## 2. Author Full first

Treat the scene's normal authored values as Full quality.

Example Sun:

```text
shadow enabled
4 splits
shadow max distance chosen for camera scale
angular distance chosen for art direction
```

Example lighthouse:

```text
SpotLight3D
shadow enabled
distance fade enabled
shadow cutoff before light cutoff
```

Example decorative village light:

```text
OmniLight3D
short range
distance fade enabled
shadow disabled unless it materially matters
```

Do not tune Minimal before Full has the intended visual result.

## 3. Apply Reduced

Map the product's Medium preset to:

```text
NucleusLightQualityProfile3D.REDUCED
NucleusViewportShadowQualityProfile3D.REDUCED
```

The default Nucleus light profile moves:

```text
Directional
    4 splits → 2 splits
    shadow range × 0.65
    angular distance × 0.50

Omni
    cube → dual paraboloid

All lights
    shadow blur × 0.75
    light size × 0.50
    volumetric fog energy × 0.50

Authored local distance fade
    begin × 0.75
    length × 0.75
    shadow cutoff × 0.65
```

The Viewport uses a 2048 positional atlas by default.

## 4. Apply Minimal

Map Low to Minimal.

Default policy:

```text
Directional
    orthogonal shadows
    shadow range × 0.35
    directional angular distance = 0
    split blending disabled

Omni
    dual paraboloid

All lights
    shadow blur × 0.50
    source-size softness = 0
    volumetric fog contribution = 0
    decorative projectors disabled

Authored local distance fade
    begin × 0.50
    length × 0.50
    shadow cutoff × 0.35
```

The Viewport defaults to a 1024 positional atlas.

If the product can ship without local real-time shadows on Low, set:

```text
minimal_atlas_size = 0
```

after validating the visual result.

## 5. Shadow-enabled ownership

For `VillageLamp`, if Nucleus is the sole shadow owner:

```text
manage_shadow_enabled = true
```

Minimal can then disable its shadow.

For the Sun, if `NucleusDaylightDriver3D` controls shadow_enabled:

```text
manage_shadow_enabled = false
```

This avoids two systems writing the same property.

## 6. Combine with caster quality

On environment meshes add:

```text
NucleusGeometryQualityController3D
```

where appropriate.

Minimal can then combine:

```text
fewer shadow casters
cheaper light-side shadows
smaller atlas
```

instead of relying on only one optimization.

## 7. Run the audit

During development:

```gdscript
var snapshot: Dictionary = NucleusLightingAudit3D.snapshot(
	self,
	get_viewport(),
)

NucleusLog.debug_data(
	"Lighting snapshot",
	snapshot,
	&"rendering",
	{"multiline": true},
)
```

Then:

```gdscript
var findings: Array[NucleusPerformanceDiagnostic] = (
	NucleusLightingAudit3D.inspect(
		self,
		get_viewport(),
	)
)
```

Investigate findings rather than blindly applying every suggestion.

## 8. Renderer-specific validation

Test every renderer the product actually ships.

Pay particular attention to:

```text
Mobile
    local light overlap per mesh

Compatibility
    projector absence
    no directional PCSS
    no AreaLight3D shadows

Forward+
    clustered element pressure
    expensive AreaLight/PCSS combinations
```

Nucleus does not hide these engine differences.

## 9. Profile

Capture the same camera route on:

```text
Full
Reduced
Minimal
```

Compare:

```text
GPU frame time
CPU frame/setup time
draw calls
shadow stability
popping/fade transitions
scene readability
```

Keep Full as the visual ceiling and make Reduced/Minimal intentional product
modes rather than emergency switches.
