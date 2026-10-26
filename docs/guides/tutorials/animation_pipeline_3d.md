# Tutorial: from imported 3D model to a working AnimationTree

This tutorial covers the practical path from an external animated character to a
working Nucleus/Godot locomotion graph.

The goal is not to hide Godot's animation system. The goal is to automate the
repetitive plumbing so time is spent on animation quality rather than scene paths
and boilerplate.

At the end you will have:

```text
stable CharacterBody3D gameplay root
reimport-safe visual wrapper
retargeted Skeleton3D
AnimationPlayer with reviewed clips
NucleusAnimationStarterProfile3D
native AnimationNodeStateMachine
idle/walk/run BlendSpace1D
optional Jump/Fall/Land states
velocity binding
optional gameplay-state binding
a graph you can continue editing normally
```

## 1. Keep the model out of gameplay ownership

Start with a gameplay shell:

```text
Player : CharacterBody3D
├── CollisionShape3D
├── MotionInput
├── Motor
└── VisualRoot : Node3D
```

The imported character belongs under `VisualRoot`.

Do not make the vendor model the root of gameplay merely because its scene
already contains a skeleton.

A robust final structure looks like:

```text
Player : CharacterBody3D
├── CollisionShape3D
├── MotionInput
├── Motor
├── VisualRoot
│   └── PlayerVisual
│       └── imported GLB scene
├── CharacterAnimationSetup3D
├── AnimationTree
├── AnimationVelocity3D
├── AnimationStateBinding
└── AnimationEvents
```

This makes later art replacement much cheaper.

## 2. Prefer a reimport-safe source layout

A useful project layout is:

```text
assets/characters/player/
    player_source.glb
    player_visual.tscn

assets/animations/humanoid/
    locomotion.glb
    combat.glb
    interactions.glb
```

Treat `player_source.glb` as imported source.

Use `player_visual.tscn` as the project-owned wrapper/inherited scene where you
keep:

```text
AnimationTree
SkeletonModifier3D nodes
BoneAttachment3D
ragdoll setup
project materials
visual-only tuning
```

Do not depend on manual edits made directly inside generated imported content
surviving a reimport.

## 3. Import the character

GLB/glTF is a good default when your source pipeline supports it.

FBX remains valid when required by the asset source.

After import, inspect the generated scene and identify:

```text
Skeleton3D
skinned meshes
AnimationPlayer
```

If the file contains several skeletons or players, decide which one is actually
the gameplay character before continuing.

## 4. Retarget humanoids in Advanced Import Settings

For a humanoid:

1. Open **Advanced Import Settings**.
2. Select the relevant `Skeleton3D`.
3. Create/assign a `BoneMap`.
4. Use `SkeletonProfileHumanoid`.
5. Inspect automatic mappings.
6. Correct missing or wrong mappings.
7. Reimport.

Do not infer a good retarget solely from bone names.

Verify at least:

```text
Hips
Spine / Chest
Neck / Head
UpperArm / LowerArm / Hand
UpperLeg / LowerLeg / Foot
left and right sides
```

Rest transforms matter as much as names.

## 5. Use Rest Fixer selectively

If the imported animation twists or scales incorrectly, inspect:

```text
Apply Node Transform
Normalize Position Tracks
Overwrite Axis
Fix Silhouette
Remove Unimportant Positions
Remove Unmapped Bones
```

Do not enable every option preemptively.

A good rule is:

```text
clean source
    minimal importer intervention

different rest pose / axes
    fix BoneMap and rest transforms first

shared animation library across rigs
    normalize only what is required for consistent retargeting
```

## 6. Organize animation clips

Godot's `AnimationPlayer` may expose keys such as:

```text
Idle
Walk
Run
Jump
Fall
Land
combat/Attack_01
movement/Humanoid_Run
```

Animation library prefixes are part of the animation key.

Nucleus preserves these keys. It does not rename imported animation resources.

If vendor names are extremely noisy, normalize names at the asset/import layer
or create a project-owned `AnimationLibrary`.

## 7. Add the setup assistant

Add:

```text
NucleusCharacterAnimationSetup3D
```

under the character scene.

Assign:

```text
visual_root = VisualRoot
```

when auto-discovery could otherwise see unrelated rigs.

The Inspector now exposes:

```text
Auto Resolve Rig
Suggest Common Clips
Build Starter Tree
Print Rig Report
```

## 8. Resolve the rig

Press:

```text
Auto Resolve Rig
```

Nucleus searches the visual branch for:

```text
Skeleton3D
AnimationPlayer
```

It also looks around the character scene for existing:

```text
AnimationTree
NucleusAnimationVelocityBinding3D
NucleusAnimationTreeStateBinding
```

The operation is non-destructive.

If several skeletons or `AnimationPlayer` nodes exist, the rig report warns that
the scene is ambiguous. Assign the intended references manually instead of
depending on the first match.

## 9. Inspect the rig report

Press:

```text
Print Rig Report
```

The report includes:

```text
number of skeletons
bone count
number of AnimationPlayers
animation keys
starter-profile warnings
```

Typical problems:

```text
0 skeletons
    wrong visual_root or import failed

multiple skeletons
    choose the actual character rig manually

0 animations
    source has no clips or animation library is elsewhere

missing required starter clip
    configure profile manually or fix animation import
```

The report is intentionally diagnostic. It does not modify the imported asset.

## 10. Suggest common clips

Press:

```text
Suggest Common Clips
```

If no starter profile exists, the helper creates:

```text
NucleusAnimationStarterProfile3D
```

The matcher fills blank roles using conservative names:

```text
Idle
Walk
Run / Jog / Sprint
Jump / Takeoff
Fall / Airborne
Land / Landing
```

Example:

```text
movement/Humanoid_Walk
    → walk_animation
```

Review every suggestion.

A clip called `Combat_Run_Attack` can contain the word `run` without being the
correct locomotion clip. Automation reduces searching; it does not replace
semantic review.

## 11. Set locomotion speeds

The starter profile contains:

```text
walk_speed
run_speed
crossfade_time
```

Match these to gameplay.

For example, if the character motor uses:

```text
walk 2.2 m/s
run  5.4 m/s
```

use approximately those thresholds in the profile.

The BlendSpace receives actual `CharacterBody3D` planar speed, so mismatched
thresholds produce obvious foot sliding or visually incorrect blending.

## 12. Build the starter tree

Press:

```text
Build Starter Tree
```

When allowed by the setup options, Nucleus creates missing:

```text
AnimationTree
NucleusAnimationVelocityBinding3D
```

Then it creates this **native Godot graph**:

```text
AnimationNodeStateMachine
├── Locomotion : AnimationNodeBlendSpace1D
│   ├── Idle @ 0
│   ├── Walk @ walk_speed
│   └── Run  @ run_speed
├── Jump     if configured
├── Fall     if configured
└── Land     if configured
```

Nothing here is a custom Nucleus animation runtime.

Open the `AnimationTree` editor and inspect it normally.

## 13. Existing trees are protected

The builder refuses to replace a non-empty `AnimationTree.tree_root` by default.

If you explicitly want to regenerate it:

```text
replace_existing_tree = true
```

Use that option carefully.

Once a generated graph has substantial manual authoring, treat it as normal
project content rather than repeatedly rebuilding it.

## 14. Understand the generated locomotion parameter

The helper wires:

```text
NucleusAnimationVelocityBinding3D.speed_parameter
    parameters/Locomotion/blend_position
```

The binding reads the existing `CharacterBody3D.velocity`.

The flow is:

```text
NucleusCharacterMotor3D
    updates CharacterBody3D.velocity
        ↓
NucleusAnimationVelocityBinding3D
    reads planar speed
        ↓
Locomotion BlendSpace1D
    Idle ↔ Walk ↔ Run
```

No duplicate motion model exists.

## 15. Test Idle → Walk → Run first

Before adding attacks, IK, or procedural animation:

1. stand still;
2. walk slowly;
3. run at full intended speed;
4. stop abruptly;
5. reverse direction;
6. rotate while moving.

Look for:

```text
foot sliding
wrong run threshold
clip cadence mismatch
visual root facing the wrong axis
unexpected root translation
bad retargeted hips/feet
```

Fix these before graph complexity grows.

## 16. Air states are travel targets, not gameplay rules

The generated Jump/Fall/Land states receive direct state-machine transitions.

They do **not** automatically decide when the actor jumps or lands.

That is intentional.

You can drive them from:

```text
NucleusStateMachine
NucleusAnimationTreeStateEffect
game-owned animation presentation logic
```

The animation graph should not secretly become the authority for jumping.

## 17. Connect an existing gameplay state machine

If gameplay already has a `NucleusStateMachine`, add:

```text
NucleusAnimationTreeStateBinding
```

Map states when necessary:

```text
gameplay       animation
idle        →  Locomotion
move        →  Locomotion
jump        →  Jump
fall        →  Fall
land        →  Land
```

The setup assistant can wire the binding to:

```text
parameters/playback
```

but it does not invent gameplay state mappings.

## 18. Add directional locomotion when the game needs it

The starter uses `BlendSpace1D` because speed-only locomotion is the most portable
baseline.

For strafing, shooters, lock-on combat, or eight-way movement, replace
`Locomotion` manually with `AnimationNodeBlendSpace2D`.

Then configure:

```text
NucleusAnimationVelocityBinding3D.blend_parameter
```

The binding already supports local X/Z velocity as a `Vector2`.

A useful graph can contain:

```text
idle
forward
backward
left strafe
right strafe
diagonals
```

Do not make the starter builder guess directional animation semantics from file
names.

## 19. Add OneShot action overlays

For discrete actions:

```text
attack
reload
interact
flinch
gesture
```

add native `AnimationNodeOneShot` branches.

Trigger them through:

```text
NucleusAnimationTreeOneShotEffect
```

from `NucleusGameplayAction` when appropriate.

This preserves:

```text
GameplayAction
    authoritative gameplay

AnimationTree OneShot
    visual presentation
```

## 20. Use animation events for authored timing

Add:

```text
NucleusAnimationEventRelay
```

An animation method track can call:

```gdscript
emit_event(&"attack_hit")
```

Local gameplay code receives the signal.

This avoids imported clips containing hardcoded paths to weapons, players, or
combat systems.

## 21. Decide root motion explicitly

The starter pipeline assumes motor-authoritative movement and therefore works
best with in-place locomotion clips.

If a clip contains root translation and the motor also moves the body, the
character can double-move or slide.

For root-motion gameplay:

```text
AnimationTree root motion
→ game-owned CharacterBody3D movement/collision policy
```

Do not enable it accidentally.

## 22. Add IK after base locomotion is stable

Use native Godot 4.7 modifiers:

```text
LookAtModifier3D
AimModifier3D
TwoBoneIK3D
CCDIK3D
FABRIK3D
JacobianIK3D
SplineIK3D
```

Examples:

```text
head tracking
weapon hand alignment
steering-wheel hands
foot targets
tentacle/spine chains
```

Keep the solver native. Nucleus should only add glue when repeated game-facing
integration proves necessary.

## 23. Attach equipment natively

Use:

```text
BoneAttachment3D
```

for:

```text
weapon visuals
backpacks
helmets
VFX anchors
hand props
camera/head anchors
```

Inventory/equipment gameplay still owns what is equipped.

## 24. Add ragdoll last

Create/tune the native physical skeleton first.

Then use:

```text
NucleusRagdollController3D
```

for runtime start/stop and partial simulation coordination.

Do not use ragdoll as a workaround for a bad rest pose or broken retarget.

## 25. Reimport safely

When the source model changes:

1. reimport the source;
2. re-check BoneMap/rest corrections;
3. run `Print Rig Report`;
4. verify animation keys still exist;
5. reopen the generated/custom AnimationTree;
6. test locomotion;
7. verify attachments and IK;
8. verify ragdoll only if skeleton proportions changed.

Do not rebuild a mature hand-authored tree unless you intentionally want to
replace it.

## 26. Troubleshooting

### Suggest Common Clips finds the wrong animation

Set the profile field manually.

Suggestions are convenience only.

### Build Starter Tree returns `ERR_ALREADY_EXISTS`

The `AnimationTree` already has a root.

Either keep editing the existing graph or enable explicit replacement.

### Build Starter Tree returns `ERR_INVALID_DATA`

Open the starter profile and verify required Idle/Walk/Run keys exist in the
resolved `AnimationPlayer`.

### Model animates but does not move between idle/walk/run

Check:

```text
AnimationVelocity3D exists
body is the gameplay CharacterBody3D
animation_tree reference is correct
speed_parameter = parameters/Locomotion/blend_position
walk/run speed thresholds are sensible
```

### Character moves twice as far as expected

Check whether the imported locomotion clips contain root translation while the
gameplay motor is also moving the body.

### Limbs twist

Return to the import/retargeting stage.

Do not compensate for broken retargeting by rotating the gameplay root.

## 27. Next steps

Once this baseline works, continue with:

- [`character_animation_3d.md`](character_animation_3d.md) for deeper IK,
  attachments, ragdoll and production replacement workflows.
- [`../animation_integration_quickstart.md`](../animation_integration_quickstart.md)
  for the compact checklist.
- [`../../components/animation_integration.md`](../../components/animation_integration.md)
  for the public ownership contract.
