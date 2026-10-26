extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_touch_player_actions()
	_test_touch_device_transition()
	_test_platform_capability_helpers_are_boolean()
	return finish()


func _test_touch_player_actions() -> void:
	var player := NucleusLocalPlayerInput.new(
		0,
		NucleusInputTypes.Source.TOUCH,
		-1,
	)

	player._set_touch_action(NucleusInputActions.MOVE_RIGHT, 1.0)
	player._set_touch_action(NucleusInputActions.MOVE_FORWARD, 1.0)

	expect_true(
		player.is_touch(),
		"Touch source should be a first-class local-player source.",
	)
	expect_true(
		player.is_action_pressed(NucleusInputActions.MOVE_RIGHT),
		"Injected touch actions should be queryable semantically.",
	)

	var move: Vector2 = player.get_vector(
		NucleusInputActions.MOVE_LEFT,
		NucleusInputActions.MOVE_RIGHT,
		NucleusInputActions.MOVE_FORWARD,
		NucleusInputActions.MOVE_BACK,
		0.0,
	)
	expect_true(
		move.length() > 0.9,
		"Touch vector should compose the same move actions as other devices.",
	)

	player._set_touch_action(NucleusInputActions.MOVE_RIGHT, 0.0)
	expect_false(
		player.is_action_pressed(NucleusInputActions.MOVE_RIGHT),
		"Releasing a touch action should clear its semantic strength.",
	)


func _test_touch_device_transition() -> void:
	var player := NucleusLocalPlayerInput.new(
		0,
		NucleusInputTypes.Source.TOUCH,
		-1,
	)
	player._set_touch_action(NucleusInputActions.MOVE_RIGHT, 1.0)

	expect_true(
		player._set_input_device(
			NucleusInputTypes.Source.KEYBOARD_MOUSE,
			InputEvent.DEVICE_ID_KEYBOARD,
		),
		"Touch seat should be able to transition back to keyboard/mouse.",
	)
	expect_true(
		player.is_keyboard_mouse(),
		"Transition should preserve the stable player object.",
	)
	expect_float(
		player.get_action_strength(NucleusInputActions.MOVE_RIGHT),
		0.0,
		"Touch strengths must be cleared when the seat leaves TOUCH.",
	)


func _test_platform_capability_helpers_are_boolean() -> void:
	expect_true(
		typeof(NucleusPlatform.supports_touchscreen()) == TYPE_BOOL,
		"Touchscreen capability query should be a boolean.",
	)
	expect_true(
		typeof(NucleusPlatform.supports_orientation()) == TYPE_BOOL,
		"Orientation capability query should be a boolean.",
	)
