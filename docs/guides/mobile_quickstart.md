# Mobile Quickstart

This guide converts an existing Nucleus character/camera setup to touchscreen
input without creating mobile-only gameplay code.

Technical contract:

```text
docs/modules/mobile.md
```

## 1. Keep your existing InputMap actions

For example:

```text
move_left
move_right
move_forward
move_back
primary_action
pause
```

Do not add `mobile_move_left` or `touch_primary_action`.

## 2. Add a touch controls layer

Example scene:

```text
TouchControls : CanvasLayer
├── MoveStick : NucleusVirtualStick
├── PrimaryAction : NucleusTouchActionButton
└── LookArea : NucleusTouchLookArea
```

For a simple global single-player game, the controls can work without a local
input session.

For the recommended stable-seat path, assign the same:

```text
NucleusLocalInputSession
player_index = 0
```

to stick/button controls that feed player 0.

## 3. Configure the virtual stick

Assign:

```text
move_left
move_right
move_up      = move_forward
move_down    = move_back
```

Tune:

```text
maximum_radius
deadzone
recenter_on_touch
```

Your existing `NucleusMotionInput.get_move_vector()` remains unchanged.

## 4. Add an action button

Set:

```text
semantic_action = primary_action
```

Optional tactile feedback:

```text
haptic_strength = 0.25
haptic_duration = 0.04
```

Because it extends `TouchScreenButton`, it can participate in multitouch gameplay
while the stick is still held.

## 5. Third-person camera look

Assign the player's existing `NucleusMotionInput` to:

```text
NucleusTouchLookArea.motion_input
```

Drag events become pointer delta consumed by the existing look rig.

No mobile camera implementation is required.

## 6. Safe area

Wrap important mobile UI with the existing:

```text
NucleusUISafeArea
```

Do not position buttons under a notch/home indicator merely because the reference
device has none.

## 7. Responsive layout

Add:

```text
NucleusUIBreakpoints
```

and use normal Godot Containers/anchors for actual layout.

A breakpoint can decide whether a mobile toolbar is compact without duplicating
the whole UI scene.

## 8. Orientation

For a scene that owns orientation:

```text
NucleusMobileOrientationPolicy
```

Example:

```text
mode = SENSOR_LANDSCAPE
```

If the whole game has one fixed orientation, the project export setting may be
enough; do not add runtime policy without a reason.

## 9. Permission request

At the moment the player enables a feature:

```gdscript
if NucleusPlatform.is_android():
    NucleusMobilePermissions.request(
        "android.permission.RECORD_AUDIO"
    )
```

Also declare required Android permissions in the export preset.

## 10. Haptics

Gameplay code can use:

```gdscript
NucleusHaptics.pulse(0.35, 0.08)
```

The existing vibration preference applies to gamepad and handheld feedback.

## 11. Sensors

Read sensors from native Godot `Input`.

Do not wait for a Nucleus wrapper if all you need is the engine value.

## 12. Test

Desktop smoke test:

```text
Input Devices / Pointing
→ Emulate Touch From Mouse
```

Then verify real device behavior for multitouch, lifecycle, safe area,
orientation, permissions, and haptics.

Continue with:

```text
docs/guides/tutorials/mobile.md
```
