# Tutorial: convert a 3D controller to mobile

We will take an existing third-person setup:

```text
Player
├── MotionInput
└── CharacterMotor3D

CameraRig
└── LookRig
```

and add mobile controls without changing the motor or camera contracts.

## Step 1 — keep the existing actions

Assume the project already uses:

```text
move_left
move_right
move_forward
move_back
primary_action
pause
```

These remain authoritative.

## Step 2 — use one local player seat

In the gameplay/session scene:

```text
GameSession
├── LocalInput : NucleusLocalInputSession
├── Player
│   └── MotionInput
└── TouchControls
```

For a one-player game:

```text
LocalInput.max_players = 1
LocalInput.reserve_keyboard_mouse_player = true
LocalInput.single_player_hot_swap = true
```

Bind the stable seat to motion input as you already would for gamepad support:

```gdscript
func _ready() -> void:
    var player_input := $LocalInput.get_player(0)
    $Player/MotionInput.bind_local_player_input(player_input)
```

Now that object may internally transition:

```text
keyboard/mouse
↔ gamepad
↔ touch
```

without replacing the reference.

## Step 3 — add the virtual stick

Add a `Control` using `NucleusVirtualStick`.

Assign:

```text
local_input_session = LocalInput
player_index = 0

move_left = move_left
move_right = move_right
move_up = move_forward
move_down = move_back
```

Give the Control a practical touch rectangle on the left side of the screen.

The stick injects strengths into the touch seat. The existing motor still calls:

```gdscript
motion_input.get_move_vector()
```

## Step 4 — add a gameplay button

Add `NucleusTouchActionButton` to the right side.

The node is a `TouchScreenButton`, so configure its normal Godot textures/shape.

Set:

```text
semantic_action = primary_action
local_input_session = LocalInput
player_index = 0
```

If `primary_action` is consumed through `NucleusGameplayActionInput`, the same
gameplay action now works for keyboard, controller, and touch.

## Step 5 — add camera touch look

Add a right-side full-height Control using `NucleusTouchLookArea`.

Set:

```text
motion_input = Player/MotionInput
sensitivity = 1.0
```

Drag the area.

The data path is:

```text
InputEventScreenDrag
→ NucleusTouchLookArea
→ NucleusMotionInput.add_pointer_delta()
→ NucleusLookRig3D
```

Tune final camera sensitivity in your game, not by forking the look system.

## Step 6 — protect the safe area

Add `NucleusUISafeArea` to the root mobile HUD.

Keep important buttons inside its adjusted content region.

Then use `NucleusUIBreakpoints` if portrait/compact layouts require a different
arrangement.

## Step 7 — add haptic confirmation

For the primary action button:

```text
haptic_strength = 0.25
haptic_duration = 0.04
```

Or call from a successful gameplay event:

```gdscript
NucleusHaptics.pulse(0.4, 0.08)
```

Feedback is more reliable when triggered by the **successful action**, not merely
the touch press, if the action can fail because of cooldown/cost/state.

## Step 8 — orientation policy

For a landscape action game, add:

```text
NucleusMobileOrientationPolicy
mode = SENSOR_LANDSCAPE
```

If a menu supports both orientations but gameplay does not, keep the orientation
node scene-owned so leaving gameplay restores the previous value.

## Step 9 — permission flow

Imagine voice chat.

Do not request microphone permission at boot.

Instead:

```text
Settings
→ Voice chat: Enable
→ explanation dialog
→ request permission
→ initialize voice feature
```

Request:

```gdscript
NucleusMobilePermissions.request(
    "android.permission.RECORD_AUDIO"
)
```

The consuming game owns the explanatory UI and result handling.

## Step 10 — lifecycle

`NucleusApp` already exposes:

```text
application_paused
application_resumed
focus_changed
back_requested
memory_warning_received
```

Use those instead of a new mobile singleton.

Examples:

```text
pause
    suspend expensive transient work

resume
    refresh platform-dependent state

back_requested
    close active modal/pause menu before considering navigation

memory warning
    release optional caches
```

## Step 11 — test device switching

Run this sequence:

1. move using touch;
2. connect/use a controller;
3. verify the same player moves from gamepad;
4. touch the stick again;
5. verify the seat returns to TOUCH;
6. release an old touch after switching and verify it does not steal ownership.

That last regression is specifically protected in the local-input contract.

## Step 12 — test multitouch

On a real phone/tablet:

```text
hold movement stick
+ hold/press primary action
+ drag look area with another finger
```

Your layout decides how many simultaneous gestures make sense. The underlying
button type is chosen to support real multitouch gameplay.

## Step 13 — choose the mobile graphics budget

Keep mobile graphics policy separate from the touch-input layer. Start with the
project renderer and viewport guidance in `docs/guides/project_configuration.md`,
then expose only preferences that are meaningful for the game's device matrix.

Useful first levers are usually:

```text
graphics/render_scale
graphics/scaling_3d_mode
graphics/max_fps
```

Environment effects such as SSAO, glow or volumetric fog remain game-owned
choices. If the game exposes them, compose `NucleusEnvironmentSettingsApplier`
with the relevant `WorldEnvironment` rather than adding mobile-only graphics
APIs.

Profile sustained play, not only the first minute. Mobile performance policy must
account for thermals, battery usage, fill rate and memory pressure.

## What remains game-specific

Nucleus does not decide:

```text
button art / opacity
left-handed mode
aim-assist strength
auto-fire
gesture vocabulary
mobile graphics profile
battery saver
store services
ads / analytics
```

Add those only when your game needs them.
