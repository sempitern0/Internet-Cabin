# Tutorial: terrain prototype and live debugging

Use the terrain debug views when generated geometry is technically valid but you
cannot tell whether a visual problem comes from height sampling, material layer
ranges, slope, texture scale, LOD, or collision.

Runnable reference:

```text
res://examples/terrain/terrain_debug_lab.tscn
```

Run it with **F6**.

## Debug views

Both `NucleusTerrainGenerator3D` and `NucleusTerrainStreamer3D` expose:

```text
Material
Height bands
Slope
Normals
Layer weights
World grid
```

They also expose:

```text
debug_wireframe
```

The same controls work in runtime. On the editor generator they also work on
existing preview/generated meshes.

### Height bands

Shows discrete colors from the profile's expected minimum/maximum height.

Use it to answer:

```text
Does the terrain actually reach the altitude where snow should start?
Is the beach range too narrow?
Is most of the generated terrain concentrated in one vertical band?
```

Increase `debug_height_bands` for finer altitude segmentation.

### Slope

Green is flatter and red is steeper.

Use it before changing a slope-driven rock layer. If the terrain never becomes
red enough, changing the rock texture will not solve the layer rule.

### Normals

Displays world normals as RGB.

Use it to find:

```text
reversed normals
unexpected normal discontinuities
lighting artifacts that are not texture problems
```

### Layer weights

Shows the four built-in terrain layers as distinct debug colors.

Approximate mapping:

```text
layer 0  sand/yellow
layer 1  green
layer 2  gray
layer 3  pale blue/white
```

Blended areas mix those colors.

**Magenta means no active layer covers that fragment.**

This is the fastest troubleshooting view when the final terrain looks like a
single color.

If Layer Weights looks correct but Material does not, inspect:

```text
albedo textures
layer tint
UV scale
Top versus Triplanar projection
texture import settings
```

### World grid

Shows a world-space checker at `debug_grid_scale`.

Use it to judge scale without relying on texture artwork.

If the grid looks tiny, terrain features/textures may be authored at the wrong
world scale even when the generation algorithm itself is correct.

### Wireframe

Enables a material overlay using Godot's wireframe render mode.

Use it to inspect:

```text
triangle density
LOD-related topology
whether increasing resolution actually changes useful silhouette
chunk boundaries
```

Do not leave wireframe enabled for normal gameplay profiling.

## Live diagnostics

The generator exposes:

```gdscript
get_debug_snapshot()
get_live_diagnostics()
```

The snapshot includes:

```text
patch count
visual resolution
triangles per patch
estimated base triangle count
collision resolution
collision samples
LOD levels
active material layers
projection mode
```

The diagnostics report common configuration risks such as:

```text
no material layers
Triplanar with several layers on weak hardware
collision denser than visual geometry
very high visual resolution
terrain shadow casting
```

These are hints, not a substitute for Godot's Profiler.

## CollisionShape3D warning

`HeightMapShape3D` grid points are one unit apart.

Older terrain generation scaled the collision node as:

```text
(cell_x, 1, cell_z)
```

which creates a non-uniform `CollisionShape3D` scale and triggers Godot's
configuration warning.

Nucleus now uses a uniform scale:

```text
(cell, cell, cell)
```

and pre-scales the height values by the inverse cell scale. This preserves world
height while keeping the collision node uniformly scaled.

Rectangular patches choose different X/Z sample counts so the cell spacing can
remain uniform.

## Debugging material layers in the editor

1. Open the terrain scene.
2. Select `NucleusTerrainGenerator3D`.
3. Set `debug_view = Layer weights`.
4. Enable `debug_wireframe` if topology also matters.
5. Press **Refresh Preview** or inspect already generated terrain.
6. Switch to `Height bands` and compare where the layer transitions occur.
7. Return to `Material`.

For a side-by-side preset comparison, open:

```text
res://examples/terrain/terrain_preview_presets.tscn
```

## Performance workflow

On weak integrated GPUs, troubleshoot in this order:

```text
1. Material → Top projection
2. disable terrain shadows
3. inspect wireframe/triangle density
4. reduce visual resolution
5. reduce visible streamed chunks
6. reduce active texture layers
7. reduce collision density only for physics cost
```

Geometry, fragment shading, shadows, and physics are different budgets.

The debug views are designed to help identify which one is actually causing the
problem.
