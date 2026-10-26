# Humanoid Ragdoll Authoring Quickstart

Use this path when a humanoid has a correct `Skeleton3D` but still needs a usable
native physical skeleton.

Canonical contract:

```text
docs/components/ragdoll_authoring_3d.md
```

## 1. Retarget first

Prefer the normal Godot import path:

```text
Skeleton3D
→ BoneMap
→ SkeletonProfileHumanoid
→ verify mapping/rest pose
```

Ragdoll authoring should not compensate for a broken retarget setup.

## 2. Add the setup helper

Near the character visual setup add:

```text
NucleusRagdollSetup3D
```

Assign:

```text
visual_root
optional BoneMap
```

Then press:

```text
Auto Resolve Ragdoll Rig
```

The helper creates a default `NucleusHumanoidRagdollProfile3D` when needed.

## 3. Inspect before generating

Press:

```text
Print Ragdoll Report
```

Confirm that required mappings exist.

Mapping priority is:

```text
manual override
→ BoneMap
→ conservative name heuristic
```

Use `manual_bone_overrides` only for exceptions.

Keys are humanoid profile names such as:

```text
Hips
Spine
Head
LeftUpperArm
LeftLowerArm
LeftUpperLeg
...
```

Values are actual Skeleton3D bone names.

## 4. Build

Press:

```text
Build Starter Ragdoll
```

The builder creates:

```text
Skeleton3D
└── PhysicalBoneSimulator3D
    ├── PhysicalBone3D
    │   └── CollisionShape3D
    └── ...
```

If a simulator already exists, the operation stops with
`ERR_ALREADY_EXISTS`.

## 5. Tune native content

Inspect the generated PhysicalBone3D nodes.

Review at least:

```text
collision shape size/orientation
joint axes
joint angular limits
mass distribution
damping
friction
collision layers/masks
```

The generator is a high-quality starting point, not final art/physics approval.

## 6. Wire runtime

Press:

```text
Wire Runtime Controller
```

The helper can create:

```text
NucleusRagdollController3D
```

and assign the simulator.

If an AnimationTree is found it is also wired.

## 7. Avoid self-collision with the gameplay body

For a character shell:

```text
CharacterBody3D
├── gameplay CollisionShape3D
└── VisualRoot / Skeleton3D / ragdoll
```

add the CharacterBody3D to:

```text
RagdollController3D.collision_exceptions
```

This uses the native simulator collision-exception API.

The game still decides when its gameplay collider/motor should be disabled.

## 8. Validate

Test:

```text
standing pose
death from several orientations
stairs/slopes
wall contact
high impulse
full ragdoll
partial ragdoll
start/stop recovery
```

A production ragdoll should be validated with the same physics backend and tick
rate that the game ships.
