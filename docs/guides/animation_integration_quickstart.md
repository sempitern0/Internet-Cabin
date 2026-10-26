# Animation Integration — 3D Quickstart

Use this after a working `CharacterBody3D` is ready for production animation.

Read in this order:

```text
animation_pipeline_3d.md
animation_directional_layers_quality_3d.md
character_animation_3d.md
```

## Baseline setup

Keep gameplay and art separate:

```text
Player : CharacterBody3D
├── gameplay collision/movement
├── VisualRoot
│   └── imported rig
├── CharacterAnimationSetup3D
├── AnimationTree
├── AnimationVelocity3D
└── AnimationEvents
```

Import/retarget the rig with Godot's native Advanced Import Settings.

Then use the setup assistant:

```text
Auto Resolve Rig
Suggest Common Clips
Build Starter Tree
```

This creates an editable native Idle/Walk/Run starter graph with optional
Jump/Fall/Land states.

## Upgrade to directional locomotion

For strafe, lock-on, shooter or multidirectional movement:

1. Add/configure `NucleusDirectionalAnimationProfile3D`.
2. Set `reference_speed` to the intended full gait speed.
3. Use `Suggest Directional Clips` as a starting point.
4. Review all assignments.
5. Press `Upgrade Locomotion To Directional`.

The helper replaces only the `Locomotion` state with `BlendSpace2D`.

It preserves the rest of the state machine.

## Add action layers natively

Create native `AnimationNodeOneShot` nodes for:

```text
attack
reload
interact
hit react
gesture
tool use
```

Author torso/bone filters in Godot.

Use `NucleusAnimationOneShotController` with semantic
`NucleusAnimationOneShotSlot` resources so gameplay calls:

```gdscript
one_shots.fire(&"attack")
```

instead of hardcoding AnimationTree parameter paths.

## Bind animation events without boilerplate

Use:

```text
NucleusAnimationEventRelay
    ↓
NucleusAnimationEventBinding(event_id)
    ↓
triggered(payload)
```

This is useful for footsteps, cosmetic impacts, sounds and local presentation.

Keep gameplay-critical authority independent from quality-dependent animation
evaluation.

## Add low-end quality policy

Add `NucleusAnimationQualityController3D`.

Register optional `SkeletonModifier3D` nodes as:

```text
full_only_modifiers
reduced_or_full_modifiers
```

Use a `NucleusAnimationQualityProfile3D` for pose update rates.

Recommended starting point:

```text
Full
    native update rate

Reduced
    30 Hz for eligible NPC presentation

Minimal
    15 Hz for distant/cosmetic actors
```

`allow_pose_throttling` is false by default. Enable it only for actors where
delayed animation callbacks cannot change gameplay correctness.

## Quality principle

On weak PCs, degrade expensive presentation before gameplay:

```text
disable optional IK/modifiers
→ lower non-critical pose update rate
→ mesh/render LOD and visibility policy
→ preserve movement/input/simulation
```

Do not turn the local player into a 15 Hz gameplay object merely to improve FPS.

## Continue

- `animation_pipeline_3d.md` — import → first graph.
- `animation_directional_layers_quality_3d.md` — directional movement, OneShots,
  event bindings and low-end quality.
- `character_animation_3d.md` — IK, attachments, ragdoll and deeper production
  workflows.
