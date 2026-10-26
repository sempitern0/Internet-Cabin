# Tutorial: Build a Humanoid Ragdoll in Minutes

This tutorial turns an imported humanoid into an editable native Godot ragdoll
without hand-authoring every PhysicalBone3D from zero.

## 1. Start from a valid humanoid

Use a wrapper/inherited character scene.

Expected visual branch:

```text
VisualRoot
└── ImportedCharacter
    └── Skeleton3D
```

Complete Godot retargeting first when the character uses a humanoid BoneMap.

## 2. Add NucleusRagdollSetup3D

Add:

```text
RagdollSetup : NucleusRagdollSetup3D
```

Assign the visual root.

If the project keeps the import `BoneMap` as a reusable resource, assign it too.

## 3. Resolve and inspect

Press:

```text
Auto Resolve Ragdoll Rig
Print Ragdoll Report
```

A healthy report should map the major chain:

```text
Hips
Spine
Head

Left/Right UpperArm
Left/Right LowerArm

Left/Right UpperLeg
Left/Right LowerLeg
```

Hands, feet, chest segments and shoulders are optional depending on the profile.

## 4. Configure the starter recipe

The default profile targets a 70 kg humanoid.

Adjust before generation when useful:

```text
total_mass
linear_damp
angular_damp
friction

include_shoulders
include_hands
include_feet

limb_thickness_scale
torso_width_scale
joint_limit_scale

flip_forward
```

Leave mirrored shape sharing disabled unless symmetric shared resources are
specifically wanted.

## 5. Generate

Press:

```text
Build Starter Ragdoll
```

Nucleus measures the rest pose and creates ordinary native nodes.

It does not replace an existing simulator.

## 6. Tune the result

Select each generated `PhysicalBone3D`.

The most important visual checks are:

```text
pelvis/torso boxes do not protrude badly
limb capsules follow the limb axis
head collider covers the skull
hands/feet are not excessively large
```

Then inspect knees and elbows:

```text
hinge axis
lower/upper angle
```

and 6DOF joints:

```text
shoulder range
hip range
spine range
head/neck range
```

The profile limits are starter constraints. Character proportions and rig axes
still require visual validation.

## 7. Wire NucleusRagdollController3D

Use the setup button or configure manually:

```text
simulator
animation_tree
```

Full death:

```gdscript
ragdoll.start_full_ragdoll()
```

Partial reaction:

```gdscript
ragdoll.start_partial_ragdoll([
	&"LeftUpperArm",
	&"LeftLowerArm",
])
ragdoll.set_ragdoll_influence(0.5)
```

## 8. Add a gameplay-body collision exception

If the authoritative `CharacterBody3D` remains present while the ragdoll
simulates:

```gdscript
ragdoll.add_collision_exception(character_body)
```

This prevents the generated bodies from fighting the gameplay body.

Whether the motor/capsule remains enabled is still game policy.

## 9. Stress-test

Try:

```text
fall from height
impact against walls
stairs
sloped terrain
impulse from front/back/side
ragdoll while airborne
partial → full ragdoll
```

Tune native shapes/joints until the character remains stable and believable.

## 10. Keep the boundary simple

Once generated, the runtime path is still:

```text
gameplay state
→ NucleusRagdollController3D
→ PhysicalBoneSimulator3D
→ PhysicalBone3D
→ Godot/Jolt physics
```

Nucleus does not stay between the engine and the generated rigid bodies.
