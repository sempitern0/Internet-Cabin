# Tutorial: replace prototype geometry with a production 3D character rig

This tutorial starts from the normal Nucleus third-person prototype and replaces
its primitive mesh with an imported humanoid while preserving the gameplay body.

At the end you will have:

```text
stable CharacterBody3D gameplay root
imported/retargeted humanoid rig
reusable AnimationTree locomotion
GameplayAction animation overlays
native Godot 4.7 IK/modifiers
BoneAttachment3D equipment anchors
full and partial ragdoll
an art-swap workflow that does not rewrite movement code
```

The examples assume a humanoid. The same ownership model works for creatures,
but humanoid retargeting uses `SkeletonProfileHumanoid` while a non-humanoid
project may need a custom `SkeletonProfile`.

## 1. Start from a gameplay shell, not from the art asset

A prototype often begins as:

```text
Player : CharacterBody3D
├── CollisionShape3D
├── PrototypeMesh : MeshInstance3D
├── MotionInput
└── Motor
```

Keep `Player` and its gameplay components.

Change only the presentation branch:

```text
Player : CharacterBody3D
├── CollisionShape3D
├── MotionInput
├── Motor
├── VisualRoot : Node3D
│   └── ImportedCharacter
├── AnimationTree
├── AnimationVelocity3D
├── AnimationStateBinding
├── AnimationEvents
└── RagdollController3D
```

Why this matters:

```text
movement/collision code
    depends on CharacterBody3D

animation/art
    depends on VisualRoot + imported rig
```

You can now replace the visual asset again later without replacing the body,
input, camera, combat, networking, or save logic.

## 2. Choose an animation source

Nucleus does not require a particular vendor.

Common prototype/production sources include:

### Mixamo

Useful for quickly obtaining standard humanoid movement/action clips.

Website:

```text
https://www.mixamo.com/
```

Treat the downloaded rig/animations as normal imported assets. Nucleus adds no
Mixamo-specific runtime code.

### KayKit Character Animations

KayKit provides reusable humanoid animation sets for movement, combat, idles,
interaction, and other common actions. Their documentation explicitly expects
engine-side retargeting when used on other humanoids.

```text
https://kaylousberg.itch.io/kaykit-character-animations
```

### Mesh2Motion

Mesh2Motion is useful when you want a browser-based/open workflow. It can
import or auto-rig models and export multiple animations bundled in GLB or FBX.

```text
https://mesh2motion.org/
```

Its current site also provides source animation files and describes its bundled
animation output as suitable for game engines.

### Your own DCC pipeline

Blender, Maya, MotionBuilder, or another DCC tool remains valid. The important
contract is that Godot receives a correctly skinned skeleton and animations that
can be mapped to the target rig.

## 3. Prefer a clean import boundary

When possible, prefer GLB/glTF for the character and animation pipeline.

A practical asset layout is:

```text
assets/characters/player/
    player.glb

assets/animations/humanoid/
    locomotion.glb
    combat.glb
    interactions.glb
```

Keeping animation libraries separate from the character mesh makes later art
replacement easier.

Treat imported model files as source assets. Put project-owned edits in an
inherited/wrapper scene instead of relying on manual edits to imported generated
content. A useful split is:

```text
player_source.glb
    reimportable source asset

player_visual.tscn
    game-owned inherited/wrapper scene
    AnimationTree / IK / attachments / ragdoll tuning
```

When you need to add modifier nodes below an imported `Skeleton3D`, use an
inherited scene or intentionally editable imported children so the ownership is
clear. Recheck those overrides after a source file changes its hierarchy.

FBX is acceptable when the source pipeline provides it. Avoid creating a custom
Nucleus conversion layer just to normalize vendor formats.

## 4. Retarget the character in Godot

Open the imported scene's **Advanced Import Settings**.

Select the `Skeleton3D`, then configure the Retarget section:

```text
Bone Map
    New BoneMap

Profile
    SkeletonProfileHumanoid
```

Godot attempts automatic mapping from common bone names.

Do not stop at "auto-map succeeded". Inspect at least:

```text
Root / Hips
Spine / Chest / UpperChest
Neck / Head
Left/Right UpperArm
Left/Right LowerArm
Left/Right Hand
Left/Right UpperLeg
Left/Right LowerLeg
Left/Right Foot
```

Missing or incorrect mappings are an import problem, not a reason to hardcode
bone-name translations in gameplay code.

Godot's 4.7 retargeting documentation:

```text
https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/retargeting_3d_skeletons.html
```

## 5. Understand the Rest Fixer options before enabling everything

Two rigs can have identical-looking bone names and still have different rest
transforms.

Important importer tools include:

```text
Apply Node Transform
Normalize Position Tracks
Overwrite Axis
Fix Silhouette
Remove Unimportant Positions
Remove Unmapped Bones
```

Do not blindly enable all of them.

A useful rule:

```text
source already imports correctly
    change as little as possible

animations distort body shape / axes differ
    inspect BoneMap and rest-fixer settings

A-pose source targeting humanoid T-pose profile
    consider Fix Silhouette and verify feet/knees manually
```

`Overwrite Axis` is powerful for shared animation libraries, but it can damage a
rig whose original rest orientation is intentionally significant.

## 6. Import animation-only files as reusable libraries

If an asset contains animation clips intended to be shared between characters,
configure it as an animation library rather than embedding a second visible
character into your gameplay scene.

Typical result:

```text
AnimationPlayer
├── RESET
├── Idle
├── Walk
├── Run
├── Jump
├── Fall
├── Attack_1
└── Interact
```

Use stable names inside your project even when the original vendor names are
verbose. Art-source naming should not leak into gameplay state IDs.

## 7. Edit vendor animations without fighting reimport

Choose the editing layer based on what must change:

```text
transition/blend behavior
    edit AnimationTree

loop, trim, clip extraction, import normalization
    edit Advanced Import Settings

keyframes / authored motion
    edit the source file in Blender/Maya/etc.
    or duplicate the clip into a project-owned AnimationLibrary first
```

Do not hand-edit an imported animation and assume those changes will survive the
next reimport. Keep authored modifications in a game-owned source file or local
AnimationLibrary when the clip must diverge from the downloaded original.

This also makes asset upgrades deliberate: reimport the vendor source, compare,
and only migrate the local changes you still want.

## 8. Build a native AnimationTree

Add an `AnimationTree` near the visual rig and point it at the imported
`AnimationPlayer`.

A good first graph is intentionally small:

```text
AnimationNodeStateMachine
├── Locomotion
├── Air
└── Death
```

Inside `Locomotion`, use either:

```text
BlendSpace1D
    idle → walk → run based on speed
```

or:

```text
BlendSpace2D
    directional locomotion based on local X/Z velocity
```

Add `AnimationNodeOneShot` branches for actions that should overlay or interrupt
locomotion:

```text
Attack
Interact
Reload
HitReact
```

Godot's AnimationTree documentation:

```text
https://docs.godotengine.org/en/4.7/tutorials/animation/animation_tree.html
```

## 9. Drive locomotion with the existing Nucleus velocity adapter

Add:

```text
NucleusAnimationVelocityBinding3D
```

Assign:

```text
body = Player
animation_tree = AnimationTree
orientation_source = Player or the visual-facing pivot
```

Then point only the parameters you actually use:

```text
speed_parameter
    parameters/Locomotion/speed

blend_parameter
    parameters/Locomotion/blend_position

grounded_parameter
    parameters/conditions/grounded

vertical_speed_parameter
    parameters/conditions/vertical_speed

moving_parameter
    parameters/conditions/moving
```

The binding reads the `CharacterBody3D.velocity` that already exists because of
movement gameplay. It does not maintain another motion model.

### Directional BlendSpace

For a `BlendSpace2D`, the binding writes:

```text
Vector2(local_velocity.x, -local_velocity.z)
```

When `normalize_blend_direction` is enabled, the direction is normalized before
being written. Use a separate speed parameter when the graph needs magnitude.

## 10. Keep gameplay states independent from animation names

If you already use `NucleusStateMachine`, add:

```text
NucleusAnimationTreeStateBinding
```

Example:

```text
gameplay state      animation state
-----------------------------------
idle                Locomotion
move                Locomotion
fall                Air
stunned             HitReactState
```

When names differ, create `NucleusStateAnimationMapping` Resources.

Do not rename gameplay states merely because a downloaded animation pack used a
different naming convention.

## 11. Fire action animations through GameplayAction

Suppose an attack already exists as a `NucleusGameplayAction`.

Add a `NucleusAnimationTreeOneShotEffect` to that action and point it at:

```text
parameters/Attack/request
```

The result is:

```text
input / AI
    ↓
GameplayAction validates requirements/cost/cooldown
    ↓
Action commits gameplay
    ↓
OneShot effect requests visual animation
```

The animation is presentation. Do not make "animation finished" the only thing
preventing an invalid attack unless the game intentionally owns that rule.

## 12. Use animation events for precise authored timing

For a sword attack, the actual hit window may need to occur at a specific frame.

Add:

```text
NucleusAnimationEventRelay
```

Create a Method Call Track in the attack animation and call:

```gdscript
emit_event(&"attack_hit")
```

Then connect locally:

```gdscript
%AnimationEvents.event_received.connect(_on_animation_event)
```

The imported animation never needs to know the path to your weapon/combat
script.

## 13. Decide in-place versus root-motion movement

For the normal Nucleus `CharacterMotor3D`, use in-place locomotion clips first.

That keeps:

```text
CharacterBody3D velocity
    authoritative for translation

AnimationTree
    authoritative for visual pose
```

If you choose root motion later, Godot can expose blended root-motion deltas via:

```gdscript
animation_tree.get_root_motion_position()
animation_tree.get_root_motion_rotation()
animation_tree.get_root_motion_scale()
```

At that point, write a game-owned movement policy that applies those deltas to
the `CharacterBody3D` with collision.

Do not leave the normal motor moving at full speed while a root-motion walk clip
also supplies displacement.

## 14. Add head look with LookAtModifier3D

Godot 4.7 Skeleton modifiers are designed to run after animation playback.

Under the imported `Skeleton3D`, add:

```text
LookAtModifier3D
```

Configure:

```text
bone_name = head or neck bone
target_node = a Node3D target
use_angle_limitation = true
```

Start with conservative yaw/pitch limits. A neck that can rotate 180 degrees
will look wrong even if the solver is working correctly.

Because this is a native modifier, its `influence` can be blended from `0` to
`1` without Nucleus owning another animation system.

## 15. Add hand/foot IK with TwoBoneIK3D

`TwoBoneIK3D` is a strong default for an arm or leg because it uses a root,
middle, end, target, and pole direction/target.

Typical arm:

```text
root   = UpperArm
middle = LowerArm
end    = Hand
target = HandTarget
pole   = ElbowPole
```

Typical leg:

```text
root   = UpperLeg
middle = LowerLeg
end    = Foot
target = FootTarget
pole   = KneePole
```

Use this for:

```text
hand placement on a weapon
hand reaching a steering wheel
foot placement target supplied by game code
fixed interaction poses
```

Nucleus does not raycast the floor or choose targets for you. Those are gameplay
or presentation policies. The IK solver itself is native Godot.

## 16. Pick a longer-chain solver only when needed

Godot 4.7 also exposes several native choices:

```text
CCDIK3D
    good rotation-based tracking and useful when joint limits matter

FABRIK3D
    precise position tracking for simple chains

JacobianIK3D
    natural/smooth multi-joint motion, but slower convergence

SplineIK3D
    path-driven tails, tentacles, spines, ropes
```

Do not build a generic "Nucleus IK" wrapper around all of these. Their native
Inspector configuration is more useful than a lowest-common-denominator API.

## 17. Respect SkeletonModifier3D ordering

Modifiers are processed as part of the `Skeleton3D` modifier stack.

If modifier B expects the pose produced by modifier A, place A before B.

A practical example:

```text
Skeleton3D
├── LookAtModifier3D
├── TwoBoneIK3D
└── PhysicalBoneSimulator3D
```

The exact order is character-specific. Test the resulting pose rather than
assuming all modifiers commute.

## 18. Attach a weapon with BoneAttachment3D

Add a native `BoneAttachment3D` under the skeleton and select the hand bone.

Then instance the visual weapon beneath it:

```text
Skeleton3D
└── WeaponSocket : BoneAttachment3D
    └── SwordVisual
```

The inventory/equipment system should still own what is equipped. The bone
attachment only owns where the visual object follows the rig.

## 19. Create the physical skeleton for ragdoll

Select `Skeleton3D` in the 3D editor and use Godot's **Create Physical Skeleton**
tooling.

The expected hierarchy is:

```text
Skeleton3D
└── PhysicalBoneSimulator3D
    ├── PhysicalBone3D
    ├── PhysicalBone3D
    └── ...
```

Then edit:

```text
collision shapes
joint type
joint orientation
joint angular limits
mass/damping where necessary
```

Remove tiny/utility physical bones that add cost without visible value. Fingers
rarely need one rigid body per joint for an ordinary death ragdoll.

Configure collision layers/masks so the gameplay `CharacterBody3D` capsule does
not fight its own active physical bones. For a death state, a game may also
change/disable the gameplay body's collision policy while ragdoll physics owns
presentation. Keep that decision in death/gameplay code rather than hiding it in
the generic animation component.

Godot ragdoll tutorial:

```text
https://docs.godotengine.org/en/4.7/tutorials/physics/ragdoll_system.html
```

## 20. Add NucleusRagdollController3D

Add the component near the player visual setup:

```text
RagdollController3D : NucleusRagdollController3D
```

Assign:

```text
simulator = ImportedCharacter/Skeleton3D/PhysicalBoneSimulator3D
animation_tree = AnimationTree
```

For a full-body death ragdoll:

```gdscript
func die() -> void:
    motor.enabled = false
    ragdoll.start_full_ragdoll()
```

By default the controller temporarily disables the assigned `AnimationTree` for
full ragdoll and restores its previous active state when stopped.

It does **not** disable your motor, collision, targeting, AI, or networking.
Those are game rules.

## 21. Use partial ragdoll for reactions

A partial simulation can affect selected skeleton bones while authored animation
continues to run.

Configure a reusable list:

```text
default_partial_bones
    LeftUpperArm
    LeftLowerArm
    LeftHand
```

Then:

```gdscript
ragdoll.start_partial_ragdoll()
ragdoll.set_ragdoll_influence(0.5)
```

Or pass an explicit list:

```gdscript
var bones: Array[StringName] = [
    &"LeftUpperArm",
    &"LeftLowerArm",
    &"LeftHand",
]
ragdoll.start_partial_ragdoll(bones)
```

The controller validates requested skeleton bone names before asking Godot to
start partial simulation. This avoids one of the native API's easy-to-miss
failure modes where an incorrect bone name simply produces no useful effect.

## 22. Stop ragdoll intentionally

For death, you may never stop it.

For a recoverable knockdown:

```gdscript
ragdoll.stop_ragdoll()
motor.enabled = true
```

A polished get-up system usually needs project-specific logic:

```text
read final body orientation
choose face-up / face-down get-up animation
reposition gameplay root
stop ragdoll
resume AnimationTree
play get-up state
restore movement at the intended frame
```

That policy is intentionally not hidden inside the generic controller.

## 23. Swapping the model later

When art changes:

1. Import the replacement model.
2. Configure its `BoneMap`/rest correction.
3. Confirm it consumes the shared animation library.
4. Replace the visual instance under `VisualRoot`.
5. Reassign `Skeleton3D`/`PhysicalBoneSimulator3D` references if paths changed.
6. Recreate/tune its physical skeleton if bone proportions differ.
7. Recheck attachments and IK targets.

You should **not** need to rewrite:

```text
CharacterMotor3D
MotionInput
camera
GameplayActions
health/inventory
network intent logic
save state
```

That is the payoff of keeping the visual rig separate from gameplay ownership.

## 24. Multiplayer rule of thumb

Do not synchronize every animated bone unless the game has a specific reason.

Normally replicate:

```text
authoritative transform/state
velocity/movement state
action/state transitions
death/ragdoll transition
```

and let each client run its local AnimationTree and IK presentation.

For a server-authoritative death, the server decides that the actor died; each
client can then start the same local ragdoll presentation.

## 25. Troubleshooting checklist

### The animation twists limbs

Check:

```text
BoneMap
rest pose
Overwrite Axis / Fix Silhouette choices
A-pose versus T-pose
unexpected position tracks
```

Do not compensate by rotating the whole gameplay body until the import pipeline
is known-good.

### The character slides while walking

Check:

```text
clip is in-place versus root-motion
motor speed versus authored stride
AnimationTree blend threshold
position-track normalization / motion_scale
```

### IK works in editor but not during animation

Check:

```text
modifier is under the correct Skeleton3D
modifier active/influence
target path
bone names
modifier ordering
AnimationTree is active
```

### Ragdoll does nothing

Check:

```text
PhysicalBoneSimulator3D exists under Skeleton3D
PhysicalBone3D children exist
collision shapes are valid
requested partial bone names exist
controller references the correct simulator
```

### Ragdoll fights the animation

For full ragdoll, let `NucleusRagdollController3D` disable the assigned
AnimationTree or disable it explicitly yourself.

For partial ragdoll, keep animation active and tune
`PhysicalBoneSimulator3D.influence`.

## 26. Validation target

A production-ready integration should survive this sequence:

```text
prototype capsule moves correctly
→ imported model replaces only visual geometry
→ idle/walk/run use real CharacterBody velocity
→ jump/fall states remain gameplay-driven
→ action OneShot fires without moving gameplay authority into animation
→ head/hand IK blends to zero without a pose pop
→ equipment follows BoneAttachment3D
→ full ragdoll starts after gameplay death
→ partial ragdoll blends with animation
→ replacement humanoid can consume the same shared animation set after retargeting
```

## Related docs

- [`third_person_3d.md`](third_person_3d.md)
- [`../animation_integration_quickstart.md`](../animation_integration_quickstart.md)
- [`../../components/animation_integration.md`](../../components/animation_integration.md)
- [`../online_replication_quickstart.md`](../online_replication_quickstart.md)
