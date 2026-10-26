extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_physical_key_roundtrip()
	_test_logical_key_roundtrip()
	_test_mouse_roundtrip()
	_test_joypad_button_roundtrip()
	_test_joypad_motion_roundtrip()
	_test_unsupported_event()
	return finish()


func _test_physical_key_roundtrip() -> void:
	var source := InputEventKey.new()
	source.physical_keycode = KEY_SHIFT
	source.location = KEY_LOCATION_LEFT
	source.ctrl_pressed = true

	var decoded := NucleusInputBindingCodec.normalize(source) as InputEventKey
	expect_true(decoded != null, "Physical key event should round-trip.")

	if decoded == null:
		return

	expect_equal(
		decoded.physical_keycode,
		KEY_SHIFT,
		"Physical keycode should survive.",
	)
	expect_equal(
		decoded.location,
		KEY_LOCATION_LEFT,
		"Key location should survive.",
	)
	expect_equal(decoded.keycode, KEY_NONE, "Logical keycode should remain empty.")
	expect_true(decoded.ctrl_pressed, "Key modifiers should survive.")


func _test_logical_key_roundtrip() -> void:
	var source := InputEventKey.new()
	source.keycode = KEY_Q
	source.alt_pressed = true

	var decoded := NucleusInputBindingCodec.normalize(source) as InputEventKey
	expect_true(decoded != null, "Logical key event should round-trip.")

	if decoded == null:
		return

	expect_equal(decoded.keycode, KEY_Q, "Logical keycode should survive.")
	expect_equal(
		decoded.physical_keycode,
		KEY_NONE,
		"Physical keycode should remain empty.",
	)
	expect_equal(
		decoded.location,
		KEY_LOCATION_UNSPECIFIED,
		"Unspecified key location should survive.",
	)
	expect_true(decoded.alt_pressed, "Logical key modifiers should survive.")


func _test_mouse_roundtrip() -> void:
	var source := InputEventMouseButton.new()
	source.button_index = MOUSE_BUTTON_RIGHT
	source.ctrl_pressed = true

	var decoded := NucleusInputBindingCodec.normalize(source) as InputEventMouseButton
	expect_true(decoded != null, "Mouse event should round-trip.")

	if decoded == null:
		return

	expect_equal(
		decoded.button_index,
		MOUSE_BUTTON_RIGHT,
		"Mouse button should survive.",
	)
	expect_true(decoded.ctrl_pressed, "Mouse modifiers should survive.")


func _test_joypad_button_roundtrip() -> void:
	var source := InputEventJoypadButton.new()
	source.button_index = JOY_BUTTON_A

	var decoded := NucleusInputBindingCodec.normalize(source) as InputEventJoypadButton
	expect_true(decoded != null, "Joypad button should round-trip.")

	if decoded == null:
		return

	expect_equal(
		decoded.button_index,
		JOY_BUTTON_A,
		"Joypad button should survive.",
	)


func _test_joypad_motion_roundtrip() -> void:
	var source := InputEventJoypadMotion.new()
	source.axis = JOY_AXIS_TRIGGER_RIGHT
	source.axis_value = -0.75

	var decoded := NucleusInputBindingCodec.normalize(source) as InputEventJoypadMotion
	expect_true(decoded != null, "Joypad motion should round-trip.")

	if decoded == null:
		return

	expect_equal(
		decoded.axis,
		JOY_AXIS_TRIGGER_RIGHT,
		"Joypad axis should survive.",
	)
	expect_float(
		decoded.axis_value,
		-1.0,
		"Axis direction should normalize.",
	)


func _test_unsupported_event() -> void:
	var source := InputEventAction.new()

	expect_false(
		NucleusInputBindingCodec.is_bindable_event(source),
		"InputEventAction should not be treated as a rebindable event.",
	)
	expect_true(
		NucleusInputBindingCodec.normalize(source) == null,
		"Unsupported events should normalize to null.",
	)
