# Tutorial: directional locomotion, action layers and animation quality

This tutorial starts from the Nucleus starter AnimationTree.

It adds three production concerns without replacing native Godot authoring:

```text
directional BlendSpace2D locomotion
semantic OneShot control
scalable animation quality for weaker hardware
```

## 1. Decide whether directional locomotion is actually needed

Keep the simpler BlendSpace1D when the character mostly moves in its facing
direction.

Use directional locomotion for:

```text
third-person shooters
lock-on melee
strafe movement
top-down 3D characters
vehicles/creatures with independent facing
```

Do not add BlendSpace2D complexity merely because it exists.

## 2. Prepare one directional gait

Create `NucleusDirectionalAnimationProfile3D`.

Required:

```text
Idle
Forward
Backward
Left
Right
```

Optional:

```text
ForwardLeft
ForwardRight
BackwardLeft
BackwardRight
```

This profile represents one gait.

If the game has separate walk/run/sprint directional packs, build multiple native
states/BlendSpaces after the scaffold instead of forcing them into one resource.

## 3. Set reference speed

Set:

```text
reference_speed
```

to the gameplay speed represented by the outer clips.

For a 5 m/s strafe set:

```text
reference_speed = 5
```

The velocity binding maps:

```text
0 m/s      → center / idle
2.5 m/s    → halfway to the directional clip
5+ m/s     → outer edge
```

This preserves useful speed magnitude inside the directional BlendSpace.

## 4. Upgrade the existing Locomotion node

On `NucleusCharacterAnimationSetup3D`:

```text
Suggest Directional Clips
Upgrade Locomotion To Directional
```

Review suggestions before upgrading.

Nucleus replaces only:

```text
Locomotion
```

with an `AnimationNodeBlendSpace2D`.

Jump/Fall/Land and state transitions remain intact.

## 5. Verify axes

Nucleus uses local velocity:

```text
X negative = left
X positive = right
Y positive = forward
Y negative = backward
```

The second axis comes from local `-Z`, matching normal Godot forward orientation.

Test all cardinal directions before diagonals.

## 6. Tune the center

Watch low-speed movement.

If the actor snaps visually from idle to full stride, check:

```text
reference_speed
blend_magnitude_reference
actual CharacterBody3D speed
```

Do not normalize every nonzero velocity to length 1 for a speed-sensitive
BlendSpace2D.

## 7. Author OneShot layers in Godot

Keep layer construction native.

A useful graph may be:

```text
base state machine
    ↓
UpperBodyAttack OneShot
    ↓
Reload OneShot
    ↓
output
```

Use filters for the bones/tracks that should receive the overlay.

Do not ask Nucleus to guess a torso mask from bone names. Imported skeletons vary
too much for that to be reliable.

## 8. Create semantic OneShot slots

Add `NucleusAnimationOneShotController`.

Create slot resources:

```text
slot_id   = attack
node_name = UpperBodyAttack

slot_id   = reload
node_name = Reload
```

Then gameplay code can use:

```gdscript
one_shots.fire(&"attack")
one_shots.abort(&"attack", true)
```

The controller derives native request/active parameter paths from the node name.

If a custom graph needs unusual parameter paths, override them in the slot
resource.

## 9. Keep action authority out of animation

A recommended attack flow:

```text
input / AI
→ GameplayAction validates
→ gameplay commits action
→ OneShotController fires presentation
```

Animation can provide authored timing events, but a graphics-quality change
should never make an otherwise valid attack disappear from simulation.

## 10. Route animation events cleanly

Keep one `NucleusAnimationEventRelay` near the visual setup.

A Method Call Track can call:

```gdscript
emit_event(&"footstep", surface_hint)
```

Add `NucleusAnimationEventBinding`:

```text
event_id = footstep
```

Connect `triggered(payload)` to a local footsteps/VFX consumer.

This avoids writing the same `if event_id == ...` handler throughout character
scripts.

## 11. Separate presentation events from simulation events

Good quality-independent presentation events:

```text
footstep sound
cloth accent
dust puff
muzzle presentation
cosmetic spark
```

Potentially gameplay-critical events:

```text
damage window
projectile spawn authority
resource spend
network authority handoff
```

If a critical event depends on an animation track, do not enable pose throttling
on that actor unless the game explicitly accepts delayed event processing.

## 12. Add animation quality control

Add:

```text
NucleusAnimationQualityController3D
```

and a:

```text
NucleusAnimationQualityProfile3D
```

Default budget:

```text
Reduced = 30 Hz
Minimal = 15 Hz
```

FULL uses the AnimationTree's original native process mode.

## 13. Register optional modifiers

Suppose the skeleton has:

```text
head LookAtModifier3D
left/right hand IK
secondary spring/bone effects
```

A reasonable policy could be:

```text
full_only_modifiers
    secondary spring effects
    cosmetic hand correction

reduced_or_full_modifiers
    head look
    important hand IK
```

Then:

```text
Full
    all authored modifiers

Reduced
    disable only full-only group

Minimal
    disable both optional groups
```

The controller restores each modifier's authored `active` state in Full.

## 14. Opt into pose throttling deliberately

`allow_pose_throttling` defaults to false.

For ambient/distant NPCs it can be useful:

```text
60/120 Hz gameplay
30 Hz animation presentation
```

or:

```text
15 Hz animation presentation for low-detail distant actors
```

The controller switches the AnimationTree to native manual mixer processing and
advances it with accumulated delta, so animation time remains correct while pose
evaluation happens less frequently.

## 15. Do not throttle the wrong actors

Good candidates:

```text
distant NPCs
ambient crowds
background creatures
non-interactive scene characters
```

Poor default candidates:

```text
local player
first-person arms
boss with animation-driven hit windows
actors using method tracks as authoritative simulation
```

For those, still use modifier quality without pose throttling.

## 16. Connect to project graphics presets

Nucleus intentionally does not introduce another global GraphicsQuality enum.

A game can map its own preset:

```text
Low
    AnimationQuality.MINIMAL

Medium
    AnimationQuality.REDUCED

High / Ultra
    AnimationQuality.FULL
```

Different actor classes may choose different mappings.

For example, the local player may always remain FULL while crowd actors follow
the graphics preset.

## 17. Combine with render-side LOD

Animation quality does not reduce mesh pixels or draw calls by itself.

For weak GPUs/CPUs combine it with:

```text
mesh LOD
visibility ranges
occlusion culling
shadow quality/budgets
render scale
ActivityGate for irrelevant actors
```

The objective is:

```text
same gameplay
same controls
same world rules
less presentation work
```

## 18. Validate low quality as a real product mode

Do not treat Low as an untested emergency switch.

Test:

```text
player control responsiveness
NPC readability
attacks remain authoritative
OneShots still make sense
no frozen visible skeletons
modifier transitions do not pop badly
15/30 Hz actors still advance in animation time
CPU frame time improves measurably
GPU bottlenecks are handled by render settings too
```

## 19. Profile before and after

Use Nucleus performance sampling plus Godot's profiler.

Compare the same representative scene with:

```text
Full
Reduced
Minimal
```

Measure frame time rather than assuming every disabled IK node is significant.

## 20. Final ownership

The resulting architecture should remain:

```text
Godot
    owns clips, graph, filters, skeleton and modifiers

Nucleus
    automates common setup
    transports semantic runtime intent
    applies optional presentation budgets

Game
    owns gameplay rules, art direction and quality preset mapping
```

That boundary keeps advanced animation reusable without turning Nucleus into an
animation engine inside Godot.
