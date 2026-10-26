# Terrain Heightmap / Material Quality Quickstart

Use this after the basic procedural terrain quickstart when a game imports real
heightmaps or PBR terrain textures.

Technical contract:

[`../modules/terrain_heightmap_materials.md`](../modules/terrain_heightmap_materials.md)

Hands-on tutorial:

[`tutorials/terrain_heightmap_materials_3d.md`](tutorials/terrain_heightmap_materials_3d.md)

## 1. Resolve terrain density from physical size

Create:

```text
NucleusTerrainResolutionPolicy
```

Then resolve one owned terrain profile:

```gdscript
var local_profile := base_profile.duplicate(true) as NucleusTerrainProfile

resolution_policy.apply_to_profile(
	local_profile,
	NucleusTerrainResolutionPolicy.Quality.REDUCED,
)
```

Do not mutate a shared profile when different terrain instances need different
quality.

## 2. Prefilter detailed heightmaps

For an imported relief texture:

```gdscript
var processed := (
	NucleusTerrainHeightmapProcessor.texture_prefiltered_for_resolution(
		relief_texture,
		local_profile.resolution,
		true,
	)
)

local_profile.image = processed
```

This reduces source frequencies the mesh cannot represent while preserving the
source image dimensions expected by normal sampling code.

## 3. Use deterministic transforms when variety needs them

```gdscript
var image := relief_texture.get_image()

image = NucleusTerrainHeightmapProcessor.transformed(
	image,
	seed % 4,
	(seed & 4) != 0,
	(seed & 8) != 0,
)
```

The game still owns why a transform is selected.

## 4. Add optional PBR terrain maps

A `NucleusTerrainTextureLayer` can now use:

```text
albedo
normal
roughness_texture
```

alongside the existing tint, blend rules, scalar roughness and metallic values.

Normal and roughness textures are optional.

## 5. Configure distance detail

On `NucleusTerrainMaterialProfile`:

```text
distance_detail_fade = true
detail_distance_start = 25
detail_distance_end = 100
```

Tune those distances from actual camera scale and GPU measurements.

## 6. Map terrain quality

For weak hardware, a useful starting point is:

```text
Full
    authored projection
    PBR detail

Reduced
    top projection
    PBR detail

Minimal
    top projection
    no normal/roughness texture samples
```

The game maps its graphics settings to
`NucleusTerrainMaterialProfile.quality`.

## 7. Reuse generated materials

Keep:

```text
reuse_generated_materials = true
```

when several terrain generators share one material profile.

Equivalent generated material requests will reuse one `ShaderMaterial`.

## 8. Validate

Check:

```text
large relief shapes remain stable after prefiltering
collision resolution is lower where gameplay permits
normal maps use OpenGL/Godot orientation
roughness fallback looks acceptable at distance
triplanar is reserved for terrain that benefits from it
Minimal remains readable and playable
material cache is not creating unnecessary variants
```

Then profile the same representative scene at Full, Reduced and Minimal.
