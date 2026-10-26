# Humanoid Ragdoll Authoring

Target engine: Godot 4.7.x.

Nucleus uses Godot's native:

```text
Skeleton3D
BoneMap / SkeletonProfileHumanoid
PhysicalBoneSimulator3D
PhysicalBone3D
CollisionShape3D
```

The authoring layer only removes repetitive setup work. Generated nodes remain
ordinary editable Godot scene content.

## Public types

Authoring:

```text
NucleusHumanoidRagdollProfile3D
NucleusRagdollRigInspector3D
NucleusRagdollBuilder3D
NucleusRagdollSetup3D
```

Runtime:

```text
NucleusRagdollController3D
```

## Preferred workflow

```text
import/retarget humanoid
        ↓
BoneMap + SkeletonProfileHumanoid
        ↓
NucleusRagdollRigInspector3D
        ↓
NucleusRagdollBuilder3D
        ↓
PhysicalBoneSimulator3D
        ↓
native PhysicalBone3D tuning
        ↓
NucleusRagdollController3D
```

`BoneMap` is the preferred semantic mapping source.

If no mapping exists, the inspector can use conservative bone-name heuristics for
common humanoid naming patterns. Heuristics are suggestions, not authority.

Manual overrides always win.

## Profile

`NucleusHumanoidRagdollProfile3D` is a generation recipe.

Defaults provide:

```text
70 kg total body mass
segment-relative mass distribution
capsule limbs/head
box torso/hands/feet
hinge knees/elbows
6DOF torso/hips/shoulders/wrists/ankles
starter angular limits
linear/angular damping
```

The profile also controls:

```text
include shoulders
include hands
include feet
mirrored shape sharing
limb thickness
torso width
minimum generated dimensions
forward-axis flip
joint-limit scale
```

These values are starter authoring policy, not runtime balance.

After generation, edit the native PhysicalBone3D nodes directly where a character
needs special tuning.

## Mass distribution

Generated physical-bone masses are normalized over the body segments that are
actually mapped and enabled.

Therefore:

```text
sum generated PhysicalBone3D.mass
    ≈ profile.total_mass
```

even when optional shoulders/hands/feet are omitted.

Mass ratios are inspired by common humanoid segment distributions, but Nucleus
does not claim biomechanical accuracy for every body type.

Stylized, armored, creature-like or exaggerated bodies should be tuned after
generation.

## Rest-pose measurement

The builder measures the authored Skeleton3D rest pose.

It derives:

```text
bone segment length
hip width
shoulder width
chain direction
terminal hand/foot/head estimates
```

Collision shapes are then fitted to those proportions.

This is intentionally generation-time work. No per-frame measurement system is
introduced.

## Shape sharing

`share_mirrored_shapes` defaults to:

```text
false
```

so editing a left-side collision shape does not unexpectedly mutate the matching
right-side shape.

Enable it only when symmetric shared resources are desirable.

## Joint policy

Knees and elbows use native hinge joints.

Other generated segments use native 6DOF starter constraints.

Nucleus does not generate active-ragdoll springs by default.

A generic "strength" parameter would mix passive ragdoll authoring with physical
animation policy and can create stability/gameplay implications. Active ragdoll
should remain a separate future system if production evidence justifies it.

## Non-destructive builder

`NucleusRagdollBuilder3D` refuses to overwrite an existing:

```text
PhysicalBoneSimulator3D
```

and returns:

```text
ERR_ALREADY_EXISTS
```

Delete or duplicate/tune the existing authored physical skeleton deliberately
before rebuilding.

The helper does not hide destructive replacement behind an editor button.

## Setup helper

`NucleusRagdollSetup3D` provides editor buttons:

```text
Auto Resolve Ragdoll Rig
Build Starter Ragdoll
Wire Runtime Controller
Print Ragdoll Report
```

The helper can create a `NucleusRagdollController3D` if requested.

Generated content receives the edited scene root as owner when possible, so it is
saved as ordinary scene content.

After setup, the helper may be removed if the scene no longer needs it.

## Inspector/report

`NucleusRagdollRigInspector3D` reports:

```text
mapping coverage
mapping source
missing required humanoid bones
existing simulator
physical-bone count
physical bones without CollisionShape3D
invalid physical-bone bone references
total physical mass
```

It does not mutate the rig.

## Runtime collision exceptions

`NucleusRagdollController3D` can now hold:

```text
collision_exceptions: Array[PhysicsBody3D]
```

and exposes:

```text
add_collision_exception()
remove_collision_exception()
sync_collision_exceptions()
```

These methods forward to `PhysicalBoneSimulator3D` native collision-exception
APIs.

Typical use:

```text
CharacterBody3D gameplay capsule
    does not collide with
active PhysicalBone3D ragdoll bodies
```

Nucleus does not disable the gameplay collider automatically. Death/knockdown
collision authority remains game-owned.

## Full versus partial ragdoll

Existing runtime behavior remains unchanged:

```text
start_full_ragdoll()
start_partial_ragdoll()
stop_ragdoll()
set_ragdoll_influence()
```

Full ragdoll may temporarily disable the configured AnimationTree.

Partial ragdoll keeps animation available and delegates influence to the native
PhysicalBoneSimulator3D.

## Networking

Replicate the semantic state by default:

```text
death
knockdown
ragdoll transition
authoritative transform/state
```

Do not replicate every physical bone unless the game's authority model genuinely
requires it.

## Performance

Physical ragdolls are physics bodies and constraints.

Avoid generating invisible complexity such as:

```text
finger rigid bodies
face bones
utility rig bones
large numbers of distant simulated corpses
```

for ordinary death presentation.

The starter profile intentionally targets major humanoid segments.

Games with many persistent corpses should combine gameplay-owned corpse lifetime
policy with existing Nucleus activity/pooling/performance tools.

## Non-goals

This layer is not:

```text
a custom physics solver
an active-ragdoll system
a get-up state machine
a universal creature-ragdoll generator
a vendor-specific rig database
automatic BoneMap authoring
runtime procedural ragdoll generation
network bone replication
```

The output should become normal Godot content as soon as the starter is built.
