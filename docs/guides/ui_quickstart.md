# UI and Accessibility Quickstart

Build the interface with native `Control`, `Container`, `Theme`, focus and
`AnimationPlayer` first. Add Nucleus components for reusable behavior, not for
visual ownership.

## Ownership layers

When layout, presentation and interaction all affect transforms, separate them:

```text
LayoutSlot          ← Container owns layout
└── PresentationRoot ← show/hide transition
    └── FeedbackRoot ← hover/focus/press/pulse
        └── Content  ← Theme/content
```

This avoids two independent systems writing the same transform.

## Presentation and feedback

Use:

```text
NucleusUIPresenter + NucleusUITransitionProfile
NucleusUIInteractionFeedback + NucleusUIFeedbackProfile
NucleusUIProgressFeedback
NucleusUIShaderEffect
NucleusUITypewriter
```

For authored multi-track sequences, keep using `AnimationPlayer`.

## World-space HUD anchors (3D)

`NucleusUIWorldAnchor3D` keeps a game-owned `Control` aligned with a `Node3D`
through a specified `Camera3D`. It rejects points behind the camera, outside
the viewport and beyond an optional distance cutoff.

To present many labels, `NucleusUIWorldAnchorLayout` provides ordered priority,
projection/visibility budgets and deterministic collision avoidance. Its
`NucleusUIWorldAnchorLayoutSolver` is pure logic that hides unplaceable labels.
The camera, 3D targets, label content and art remain game-owned.

Use a plain HUD `Control` as the overlay and add each position-controlled label
as a *direct child*. Disable each anchor's `update_automatically` option when a
layout coordinates it. Do not tween the position on the same Control.

See [`../components/ui_world_anchors.md`](../components/ui_world_anchors.md)
for the full composition, APIs, limitations and validation checklist.

Visual test scene: `examples/ui/world_anchor_lab.tscn`. It generates eight moving
3D entities with nameplates and lets you inspect collision handling in-game.

## Input prompts and glyphs

`NucleusInputGlyphBinding` follows the active keyboard/gamepad/touch source and
gamepad family. Glyph artwork is game-owned. Keep the optional human-readable
text fallback so an icon pack is never the only way to understand an action.

## Accessibility preferences

Built-in preferences include:

```text
accessibility/reduced_motion
accessibility/ui_motion_scale
accessibility/screen_flash_intensity
accessibility/ui_scale
accessibility/high_contrast
```

`ui_scale` and `high_contrast` express user intent. Nucleus deliberately does not
scale an entire `Control` root or impose a universal contrast palette. Compose
`NucleusUIAccessibilityBinding` and map those values into the game's Theme and
responsive layout strategy.

Essential state should not depend on color alone; combine color with text, icon,
shape, pattern or another redundant cue.

## Reduced motion

Nucleus UI motion uses the shared reduced-motion policy. Each motion profile can
choose how much nonessential movement remains through `reduced_motion_scale`.
Camera feedback has the same policy boundary.

## Signal-driven UI and coalescing

Prefer:

```text
runtime state changes
→ signal
→ binding / local refresh
```

over per-frame HUD polling.

When several signals update the same expensive presentation in one frame,
`NucleusUIRefreshCoalescer` can collapse them into one deferred refresh. Do not
coalesce focus, confirmation or modal ownership when a one-frame delay changes
interaction correctness.

`NucleusUIResourceLoadBinding` can optionally coalesce high-frequency progress
updates through `coalesce_progress_updates`.

## Focus and navigation

Keep native Godot focus authoritative. Use Nucleus focus helpers to reduce
repeated setup, not to build another navigation engine.

## Validate manually

Run:

```text
examples/ui/ui_polish_lab.tscn
```

Test mouse, keyboard and controller hot-swap, focus traversal, missing-glyph text
fallback, reduced motion, UI scaling and the game's high-contrast presentation.

Hands-on: [`tutorials/ui_polish.md`](tutorials/ui_polish.md).
