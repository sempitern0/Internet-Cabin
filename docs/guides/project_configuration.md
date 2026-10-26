# Recommended Godot project configuration

Nucleus does not replace Godot project settings. This guide gives starting points
for common project types and explains which choices remain game-owned.

## Ownership rule

Use `project.godot` for startup-time engine policy, `NucleusSettings` for
user-changeable runtime preferences, and scene resources for scene-owned visual
policy. Do not mirror every ProjectSettings key into Nucleus.

## Baseline matrix

| Project type | Renderer | Base viewport | Stretch | Notes |
| --- | --- | --- | --- | --- |
| 2D general | Compatibility or Forward+ | game-specific | canvas_items | Keep assets/UI resolution-aware. |
| Pixel art | Compatibility is often enough | integer-friendly | canvas_items | Prefer nearest filtering and integer scales. |
| Desktop 3D | Forward+ | 1080p-class starting point | canvas_items | Expose runtime quality only when it has player value. |
| Mobile 3D | Mobile | device/aspect aware | canvas_items | Budget fill rate, effects, thermals and memory first. |
| Tablet | Mobile or Forward+ after profiling | aspect aware | canvas_items | Treat large tablets separately from low-end phones. |

These are starting points, not framework requirements. Measure on target hardware.

## Resolution and stretch

Nucleus defaults to Godot's native viewport/window model. Pick a logical viewport
that suits the game, then test all supported aspect ratios. `canvas_items` with
`expand` is a useful general baseline for responsive UI, but pixel-art games may
need stricter integer scaling rules.

For 3D, prefer `graphics/render_scale` over changing the logical UI resolution at
runtime. It changes the 3D render buffer while leaving 2D/UI at full viewport
resolution.


## Window resolution versus 3D render resolution

Nucleus does not ship a fixed `display/resolution` option in the default catalog.
A useful desktop resolution list depends on the active monitor, window mode,
platform, aspect policy, and whether the game supports arbitrary window sizes.
Web and mobile targets are usually managed by the host/platform instead.

If a desktop game needs a resolution picker, keep that policy in the consuming
game and apply the chosen window size through the appropriate `DisplayServer`
runtime API. Do not confuse it with `graphics/render_scale`: render scale changes
only the 3D render buffer and is suitable for performance/quality adjustment
without changing the logical UI viewport.

## Renderer choice

Use Forward+ when desktop 3D features such as SDFGI, SSIL or volumetric effects
matter. Use Mobile when targeting mobile GPUs or when the feature/performance
tradeoff is appropriate. Compatibility remains valuable for broad hardware and
many 2D projects.

Do not expose a setting whose engine feature is unavailable in the selected
renderer. Hiding unsupported choices is better UX than presenting a toggle that
cannot affect rendering.

## Physics and frame rate

Physics tick rate is game policy, not a graphics preference. Keep it stable unless
the simulation has a measured reason to change. Runtime FPS limiting belongs to
`graphics/max_fps`; VSync belongs to `display/vsync_mode`.

Do not use quality presets to alter deterministic gameplay physics.

## Anti-aliasing

Nucleus exposes the root viewport mechanisms rather than a synthetic "AA quality"
integer:

- `graphics/screen_space_aa`: Disabled, FXAA or SMAA;
- `graphics/taa_enabled`: native TAA toggle;
- `graphics/msaa_2d`: 2D MSAA;
- `graphics/msaa_3d`: 3D MSAA.

Games decide which combinations are sensible. Avoid enabling multiple expensive
methods merely because they are available.

## 3D resolution scaling

`graphics/scaling_3d_mode` selects Bilinear, FSR 1, FSR 2 or Nearest.
`graphics/render_scale` controls the scale. Native resolution is `1.0`.

FSR modes are intended primarily for scales below `1.0`. Bilinear can also be
used above `1.0` for supersampling. Nearest is useful for deliberately crisp or
retro 3D presentation and works best at integer-divisor scales.

MetalFX is not in the default catalog because it is platform/driver-specific.
A macOS/iOS game can add its own option when its supported-device matrix proves
that choice is appropriate.

## Environment effects

SSAO, SSIL, glow, volumetric fog, SDFGI and tonemapping belong to an `Environment`
resource. Nucleus therefore ships their definitions as optional resources and a
scene-owned `NucleusEnvironmentSettingsApplier`; they are not forced into the
default global catalog.

This keeps an artist-authored `WorldEnvironment` authoritative until the game
explicitly opts into user-controlled environment settings.

## Mobile checklist

- profile on representative low/mid/high devices;
- respect safe areas with `NucleusUISafeArea`;
- use UI breakpoints for phone/tablet layouts;
- feed touch controls into the same semantic InputMap actions;
- prefer conservative 3D render scale/effects before lowering UI resolution;
- test pause/resume, orientation and memory pressure paths;
- verify haptics and permissions only on platforms that support them.

See `docs/guides/tutorials/mobile.md` for the composition flow.
