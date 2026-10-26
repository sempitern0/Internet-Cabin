# Tutorial: scalable heightmaps and PBR terrain

This tutorial takes a high-resolution authored relief image and a small PBR
surface set and turns them into terrain that scales from high-end to modest PCs.

## 1. Start with physical terrain dimensions

Suppose the terrain footprint is:

```text
600 m × 450 m
```

Do not choose mesh resolution solely from the source texture dimensions.

A 2K heightmap does not imply a 2048-cell terrain mesh.

Create a `NucleusTerrainResolutionPolicy`.

A useful initial policy might target:

```text
Full      2.5 m/cell
Reduced   4.0 m/cell
Minimal   6.0 m/cell
```

with visual bounds such as:

```text
32–256 cells
```

and a lower collision ratio.

## 2. Duplicate shared profiles before changing quality

If an authored base profile is shared:

```gdscript
var terrain_profile := (
	base_profile.duplicate(true)
	as NucleusTerrainProfile
)
```

Then:

```gdscript
resolution_policy.apply_to_profile(
	terrain_profile,
	quality,
)
```

This avoids quality changes leaking into other terrain actors.

## 3. Inspect the actual sample budget

For:

```text
resolution = 160
```

the mesh samples approximately:

```text
161 × 161 height points
```

If the source heightmap is 2048×2048, most high-frequency source detail cannot
survive as geometry.

## 4. Prefilter the heightmap

Use:

```gdscript
var source_image := relief_texture.get_image()

var filtered := (
	NucleusTerrainHeightmapProcessor.prefilter_for_resolution(
		source_image,
		terrain_profile.resolution,
		true,
	)
)

terrain_profile.image = ImageTexture.create_from_image(filtered)
```

The processor downsamples with Lanczos to the representable sample budget, then
optionally restores source dimensions with cubic interpolation.

This is an anti-aliasing step for height data, not a blur effect added for style.

## 5. Add deterministic visual variation

For a family of compatible relief images, quarter rotations and mirrors can
produce deterministic variety:

```gdscript
var variant := NucleusTerrainHeightmapProcessor.transformed(
	source_image,
	seed % 4,
	(seed & 4) != 0,
	(seed & 8) != 0,
)
```

Do not use transforms when the relief has authored north/south semantics,
coastline connectivity, roads, or other directional constraints.

## 6. Keep artistic composition outside Nucleus

A game may combine:

```text
base relief
detail noise
shape mask
erosion mask
shoreline mask
```

before the generic prefilter.

The semantics of those maps remain game-owned.

Nucleus only handles reusable image preparation.

## 7. Build terrain PBR layers

Create `NucleusTerrainTextureLayer` resources.

Example ground layer:

```text
albedo = grass_color
normal = grass_normal_gl
roughness_texture = grass_roughness

roughness = 0.9
roughness_texture_strength = 1.0
normal_strength = 0.45

height_range = (0.10, 0.80)
slope_range = (0.00, 0.55)
```

The scalar roughness remains the fallback when distance/quality disables the
texture.

## 8. Verify normal-map orientation

Godot expects OpenGL-style tangent normals.

Prefer:

```text
NormalGL
```

when an asset pack contains both GL and DX variants.

If only a DirectX normal exists, convert it through the Godot importer.

Do not add a game-specific Y-flip branch to every terrain shader.

## 9. Configure projection

Use:

```text
Top projection
```

for mostly horizontal terrain or weak hardware.

Use:

```text
Triplanar
```

when steep cliffs visibly stretch top-projected textures enough to justify the
extra samples.

## 10. Configure detail distance

Start with:

```text
detail_distance_start = 25 m
detail_distance_end = 100 m
```

Near the camera:

```text
albedo
normal detail
roughness texture
```

Far away:

```text
albedo
scalar roughness
geometric normal
```

This reduces PBR texture work without changing terrain identity.

## 11. Configure quality tiers

Default built-in behavior is:

```text
FULL
    authored projection
    normal/roughness detail

REDUCED
    top projection
    normal/roughness detail

MINIMAL
    top projection
    no normal/roughness detail
```

For a cliff-heavy game, Reduced can opt back into triplanar.

For an extremely constrained target, Reduced can also disable detail textures.

## 12. Share the material profile

If multiple terrain actors use the same material rules, share one:

```text
NucleusTerrainMaterialProfile
```

Keep:

```text
reuse_generated_materials = true
```

Equivalent terrain material requests now reuse the same generated
`ShaderMaterial`.

The cache still creates separate entries when height ranges, quality or layer
configuration differ.

## 13. Understand what the cache does not do

The cache does not merge incompatible materials.

These remain separate variants:

```text
different quality
different height normalization
different PBR textures
different layer blend ranges
different debug view
```

This avoids visual corruption for the sake of an artificial material-count goal.

## 14. Test low quality deliberately

Run the same camera path at:

```text
Full
Reduced
Minimal
```

Check both image quality and timing.

Look for:

```text
visible cliff stretching
roughness popping
normal-detail popping
terrain silhouette changes
collision mismatch
obvious visibility seams
```

The first three are presentation tuning.

The last three indicate a geometry/policy problem.

## 15. Profile CPU and GPU separately

Resolution primarily affects:

```text
CPU mesh build
vertex memory
collision build when linked
GPU vertex work
```

PBR/triplanar policy primarily affects:

```text
fragment texture sampling
GPU bandwidth
shader cost
```

Do not solve a CPU generation spike only by removing normal maps.

Do not solve a fragment-shader bottleneck only by lowering collision resolution.

## 16. Final composition

A scalable terrain actor can now be built from:

```text
game-owned terrain descriptor
        ↓
ResolutionPolicy
        ↓
HeightmapProcessor
        ↓
TerrainProfile
        ↓
TerrainGenerator3D
        ↓
TerrainMaterialProfile
    ├── PBR layers
    ├── detail distance
    ├── quality policy
    └── material reuse
```

The next layer, when a real world-streaming consumer requires it, is bounded
materialization across frames. That belongs to streaming/runtime budgeting, not
to this material/heightmap contract.
