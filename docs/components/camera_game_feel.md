# Camera and Game Feel Feedback

Target engine: Godot 4.7.x.

The feedback layer adds presentation impulses without teaching camera systems
what gameplay concepts such as recoil, landing, damage, or abilities mean.

## Components

```text
NucleusMotionPolicy

NucleusCameraImpulseProfile2D
NucleusCameraImpulseProfile3D

NucleusCameraFeedback2D
NucleusCameraFeedback3D

NucleusCameraImpulseEffect2D
NucleusCameraImpulseEffect3D

NucleusCameraBob2D
NucleusCameraBob3D

NucleusLandingFeedback2D
NucleusLandingFeedback3D
```

`NucleusCameraFov3D` is also extended with source-owned additive offsets.

## Shared accessibility policy

Reduced-motion detection now lives in:

```text
NucleusMotionPolicy
```

It combines:

```text
DisplayServer accessibility preference
+
Nucleus accessibility/reduced_motion setting
```

The existing `NucleusUIMotionPolicy` delegates reduced-motion detection to this
shared policy.

UI-specific motion scale and flash intensity remain UI concerns.

Gameplay camera feedback therefore reuses the same accessibility decision
instead of duplicating it.

## Feedback ownership

`NucleusCameraFeedback2D/3D` are additive mixers.

They combine:

```text
temporary impulses
+
continuous offset sources
```

and apply one final presentation offset.

This prevents:

```text
weapon recoil
landing kick
head bob
damage shake
```

from writing the same camera transform independently.

## Dedicated target rule

3D feedback should normally own a dedicated Node3D pivot.

Example third person:

```text
ThirdPersonCameraRig3D
└── FeedbackPivot
    └── SpringArm3D
        └── Camera3D
```

`ThirdPersonCameraRig3D` continues owning follow/orbit.

`SpringArm3D` continues owning collision shortening.

`FeedbackPivot` owns additive game-feel transform only.

The Camera3D remains a direct child of SpringArm3D.

## 2D compatibility

`NucleusCameraFollow2D` moves its Camera2D directly.

When `NucleusCameraFeedback2D.target` is a Camera2D and
`use_camera_offset` is enabled, feedback writes:

```text
Camera2D.offset
```

instead of position.

This allows Follow and feedback to compose without competing for position.

Rotation feedback is disabled by default in this mode because a follow system
may also own camera rotation.

For a custom 2D rig with a dedicated feedback pivot, disable
`use_camera_offset` and enable rotation when appropriate.

## Impulse profiles

Profiles are Resources and may be reused by many actions/actors.

They contain two types of contribution.

### Deterministic kick

```text
position kick
rotation kick
3D FOV kick
```

Use for:

```text
recoil
landing kick
dash kick
explosion push
```

### Procedural shake

```text
position amplitude
rotation amplitude
optional 3D FOV noise
frequency
```

The runtime uses Godot `FastNoiseLite`.

Every impulse decays using:

```text
(1 - progress) ^ decay_power
```

Profiles may use a fixed noise seed for reproducible presentation or `0` for a
runtime seed.

## Stackable impulses

Calling:

```gdscript
feedback.play_impulse(profile, strength)
```

does not replace an existing impulse.

Outputs are summed.

Therefore:

```text
weapon recoil
+
damage impact
+
explosion shake
```

can coexist naturally.

## Continuous sources

Feedback also exposes source-owned offsets:

```gdscript
set_offset_source(source_id, ...)
remove_offset_source(source_id)
```

This follows the same ownership principle used by:

```text
Attribute modifier sources
GameplayAction blockers
CameraFov offsets
Targeting candidate sources
```

One producer cannot remove another producer's contribution accidentally.

`NucleusCameraBob2D/3D` uses this API.

## FOV integration

`NucleusCameraFeedback3D` never writes `Camera3D.fov` directly.

It owns one offset source in:

```text
NucleusCameraFov3D
```

The effective target becomes:

```text
primary target FOV
+
sum(source-owned FOV offsets)
```

This allows systems such as:

```text
ADS / sprint target FOV
+
temporary recoil FOV
+
explosion FOV impulse
```

without overwriting one another.

Existing `set_target_fov()` and `reset_fov()` behavior remains intact.

## Locomotion bob

Bob adapters read native CharacterBody velocity.

They do not depend on the internals of Nucleus motors.

3D bob can require `is_on_floor()`.

Bob intensity scales with movement speed and eases toward the target weight
through existing `NucleusMotionMath.exponential_weight()`.

It submits one continuous feedback source instead of moving the camera itself.

## Landing feedback

Landing adapters detect:

```text
previously airborne
→ now on floor
```

and use the previous velocity projected against `CharacterBody.up_direction` to
measure impact.

Impact speed is normalized between:

```text
minimum_impact_speed
full_strength_speed
```

and becomes impulse strength.

The adapter does not modify movement state.

## GameplayAction integration

Camera impulse Action effects derive from:

```text
NucleusActionEffect
```

Example:

```text
FireWeapon : GameplayAction
├── AmmoCost
├── Cooldown
├── SpawnProjectile
├── FireAnimation
└── CameraImpulse
```

A context key may optionally multiply impulse strength.

No weapon-specific camera script is required.

## Accessibility behavior

Every impulse profile and continuous source can independently decide whether to
respect reduced motion.

When enabled, amplitude is multiplied by its configured:

```text
reduced_motion_scale
```

rather than forcing all motion to zero.

This allows projects to retain orientation feedback while substantially reducing
camera displacement.

A profile may set the reduced scale to `0` if the effect should disappear
entirely under reduced motion.

## What feedback does not own

Not included:

```text
camera targeting/lock rotation
cinematic camera sequencing
weapon spread
damage rules
rumble
post-processing
screen flashes
```

Those systems may trigger feedback, but do not belong inside the camera mixer.
