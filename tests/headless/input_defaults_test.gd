extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_ui_gamepad_defaults()
	_test_movement_gamepad_defaults()
	_test_gamepad_rebinds_are_device_agnostic()
	return finish()


func _test_ui_gamepad_defaults() -> void:
	expect_true(
		_has_joypad_button(NucleusInputActions.UI_ACCEPT, JOY_BUTTON_A),
		"ui_accept should default to the south face button.",
	)
	expect_true(
		_has_joypad_button(NucleusInputActions.UI_CANCEL, JOY_BUTTON_B),
		"ui_cancel should default to the east face button.",
	)


func _test_movement_gamepad_defaults() -> void:
	expect_true(
		_has_joypad_axis(NucleusInputActions.MOVE_LEFT, JOY_AXIS_LEFT_X, -1.0),
		"Move left should include left-stick X-.",
	)
	expect_true(
		_has_joypad_axis(NucleusInputActions.MOVE_RIGHT, JOY_AXIS_LEFT_X, 1.0),
		"Move right should include left-stick X+.",
	)
	expect_true(
		_has_joypad_axis(NucleusInputActions.MOVE_FORWARD, JOY_AXIS_LEFT_Y, -1.0),
		"Move forward should include left-stick Y-.",
	)
	expect_true(
		_has_joypad_axis(NucleusInputActions.MOVE_BACK, JOY_AXIS_LEFT_Y, 1.0),
		"Move back should include left-stick Y+.",
	)


func _test_gamepad_rebinds_are_device_agnostic() -> void:
	var source := InputEventJoypadButton.new()
	source.device = 7
	source.button_index = JOY_BUTTON_X

	var normalized := (
		NucleusInputBindingCodec.normalize(source) as InputEventJoypadButton
	)
	expect_true(normalized != null, "Joypad binding should normalize.")

	if normalized:
		expect_equal(
			normalized.device,
			NucleusInputBindingCodec.INPUT_MAP_ALL_DEVICES,
			"Runtime gamepad rebinds should work on any controller device id.",
		)


func _has_joypad_button(action: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if (
			event is InputEventJoypadButton
			and (event as InputEventJoypadButton).button_index == button
		):
			return true

	return false


func _has_joypad_axis(
	action: StringName,
	axis: int,
	direction: float,
) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if not (event is InputEventJoypadMotion):
			continue

		var motion := event as InputEventJoypadMotion

		if (
			motion.axis == axis
			and signf(motion.axis_value) == signf(direction)
		):
			return true

	return false
