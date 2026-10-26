# Tutorial: texture and material optimization for scalable 3D quality

This tutorial builds a practical asset/rendering workflow around Godot's native
importer and renderer.

The objective is:

```text
high-quality authored result
+
shared materials
+
measurable low-end degradation
+
no hidden runtime asset mutation
```

## 1. Start with evidence

Profile a representative scene before changing textures or shaders.

Capture:

```text
frame time / frame pacing
video memory
draw calls
rendered objects
primitives
```

Texture and material work should address a measured or plausible bottleneck, not
a superstition such as "all 4K textures are bad".

## 2. Audit a focused asset directory

Create a budget resource and run:

```gdscript
var findings := NucleusTextureAudit.inspect_directory(
	"res://assets/characters",
	texture_budget,
	true,
)
```

A focused directory is preferable to scanning the whole game during ordinary
iteration.

## 3. Review texture dimensions

For every large texture ask:

```text
How large is it on screen?
How close can the camera get?
Is it reused widely?
Is it a hero asset?
Could UV density or tiling solve this better?
```

A texture should earn its resolution.

## 4. Review mipmaps

For ordinary 3D textures, mipmaps are usually desirable.

They improve distant sampling and reduce aliasing while adding memory overhead.

Keep explicit exceptions explicit.

## 5. Review compression

For normal 3D assets, compare visual quality with GPU-friendly compression.

Do not confuse file size with VRAM size:

```text
lossy file compression
    may make the project/download smaller

VRAM compression
    directly targets GPU texture memory/bandwidth
```

Use the importer as the authority.

## 6. Treat normal maps as data

Normal maps deserve correct import handling.

If a filename strongly looks like a normal map but normal-map detection is
disabled, the audit reports it for review.

Do not enable normal compression blindly for textures whose blue channel or
custom packing has project-specific meaning.

## 7. Find material duplication

Run:

```gdscript
var findings := NucleusRenderAudit.inspect(character_or_world_root)
```

If many `ShaderMaterial` resources share one `Shader`, inspect why.

Common bad pattern:

```text
Enemy01 Material
    damage = 0.1

Enemy02 Material
    damage = 0.4

Enemy03 Material
    damage = 0.8
```

with three duplicated materials.

## 8. Move scalar/vector variation to instance uniforms

Shader:

```glsl
shader_type spatial;

instance uniform vec4 team_color : source_color = vec4(1.0);
instance uniform float wetness = 0.0;

void fragment() {
	ALBEDO = team_color.rgb;
	ROUGHNESS = mix(0.8, 0.2, wetness);
}
```

Runtime:

```gdscript
material_binding.set_parameters({
	&"team_color": team_color,
	&"wetness": wetness,
})
```

Now objects can retain the shared material/shader.

## 9. Keep textures material-owned

Do not use instance uniforms for:

```text
albedo texture
normal texture
arrays
texture sets
```

When objects genuinely use different texture resources, separate materials may be
the correct solution.

## 10. Build three material tiers

Author project materials deliberately.

Example:

```text
CharacterFull
    base maps
    detail normal
    secondary procedural detail
    advanced skin/cloth response

CharacterReduced
    base maps
    normal + ORM
    simpler shader

CharacterMinimal
    base color
    roughness
    inexpensive lighting path
```

Put them in `NucleusMaterialQualityProfile3D`.

A null Full material can preserve the production-authored override.

## 11. Apply material quality

Add:

```text
NucleusMaterialQualityController3D
```

Assign target + profile.

The controller captures the original material override and can return to it.

This is important for editor-authored scenes where the Full material is already
correct.

## 12. Add geometry quality independently

Material cost and geometry cost are different axes.

Add:

```text
NucleusGeometryQualityController3D
```

Start conservatively:

```text
Full
    LOD scale 1.0
    authored shadows
    authored visibility

Reduced
    LOD scale 0.75

Minimal
    LOD scale 0.5
    shadows off where acceptable
    optional visibility cap
```

Profile the visual result.

## 13. Understand LOD bias

Nucleus multiplies the authored native `lod_bias`.

It does not swap meshes manually.

This keeps Godot's native LOD system responsible for choosing the actual mesh
detail.

## 14. Use visibility caps only for valid content

Good candidates:

```text
small props
minor vegetation
distant debris
cosmetic clutter
```

Poor candidates:

```text
large landmarks
navigation-critical objects
objectives
silhouette-defining architecture
```

A low setting must remain playable.

## 15. Audit transparency

Transparent geometry can become expensive through overdraw and sorting.

Review:

```text
foliage
glass
water effects
particles
decals
hair cards
```

When art allows:

```text
opaque
or
alpha scissor
```

can be preferable to broad alpha blending.

Do not convert semi-transparent art blindly.

## 16. Pair with animation/AI quality

For a weak PC a crowd actor might use:

```text
AI decision
    staggered / lower frequency

Animation
    REDUCED or MINIMAL

Material
    REDUCED or MINIMAL

Geometry
    earlier LOD / no shadow
```

while the local player remains:

```text
Animation FULL
Material FULL
Geometry FULL
```

The systems compose without sharing hidden policy.

## 17. Avoid shader-switch hitches

If Reduced/Minimal materials use different shaders, the first visible use may
compile a new pipeline.

Test transitions during representative gameplay.

When measurement proves first-use compilation is a problem, use the existing
Nucleus warmup/loading flow or a game-authored rendered warmup scene.

Do not add permanent hidden rendering merely "just in case".

## 18. Validate the Low preset

A proper Low preset should be tested as a product configuration:

```text
weak integrated GPU
limited VRAM/shared memory
representative combat/crowd scene
representative exterior/interior
menu → gameplay transitions
```

Measure and visually inspect.

## 19. Keep the boundary clean

Final ownership:

```text
Godot importer
    texture format / mipmap / compression implementation

Godot renderer
    materials / shaders / native LOD / transparency

Nucleus
    diagnostics
    reusable instance-uniform binding
    reversible quality policy

Game
    asset resolution
    shader art direction
    quality tier content
    preset mapping
```

This keeps optimization reusable without hiding the actual rendering system.
