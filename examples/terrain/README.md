# Terrain examples

These scenes are intentionally small and independent of external demo heightmaps.

## Preview scenes

Open these in the editor:

```text
terrain_preview.tscn
    one cheap island preview

terrain_preview_presets.tscn
    four reusable terrain presets side by side
```

## Runnable scenes

Run with F6:

```text
terrain_single.tscn
terrain_grid.tscn
terrain_linear.tscn
terrain_islands.tscn
terrain_material_layers.tscn
terrain_streaming.tscn
terrain_debug_lab.tscn
```

## Debug lab

`terrain_debug_lab.tscn` is the visual troubleshooting scene.

Its UI can switch live between:

```text
Material
Height bands
Slope
Normals
Layer weights
World grid
```

and toggle wireframe/triangle display.

The stats panel reports topology/material information plus live diagnostic hints.

Use **Layer weights** first when the final terrain appears to ignore configured
height-based textures. Magenta means no layer rule covers that surface.

## Material reference

`terrain_material_layers.tscn` and the debug lab use:

```text
materials/terrain_height_layers.tres
```

with four deliberately distinct texture/tint bands:

```text
sand
grass
rock
snow/high-altitude
```

## Streaming

`terrain_streaming.tscn` is the runtime streaming demo. An orange tracked marker
moves along +Z while the HUD shows loaded and pending chunks.

## Performance notes

On weak integrated GPUs, start with:

```text
resolution = 48 to 64
lod_levels = 2
Top projection
terrain shadows disabled
collision debug visualization disabled unless needed
```

Use the debug lab to identify whether the limiting cost is geometry, material
projection/layers, or scene-level shadowing before reducing everything at once.
