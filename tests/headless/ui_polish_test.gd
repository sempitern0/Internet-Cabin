extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_transition_profile_builders()
	_test_presenter_immediate_compatibility()
	_test_visual_state_math()
	_test_progress_feedback_immediate()
	_test_interaction_selected_state()
	_test_input_glyph_profile_resolution()
	_test_shader_effect_value_contract()
	_test_typewriter_immediate_and_skip()
	_test_typewriter_punctuation_cadence()
	_test_typewriter_button_replay_and_skip()
	_test_typewriter_skip_after_reset()
	return finish()


func _test_transition_profile_builders() -> void:
	var fade := NucleusUITransitionProfile.fade_only(0.3)
	expect_true(fade.fade, "Fade transition keeps opacity animation enabled.")
	expect_false(fade.use_scale, "Fade-only transition disables scale.")
	expect_float(
		fade.get_motion().duration,
		0.3,
		"Fade builder preserves the requested duration.",
	)

	var slide := NucleusUITransitionProfile.slide(
		Vector2(24.0, -8.0),
		0.2,
		false,
	)
	expect_true(slide.use_offset, "Slide transition enables positional offset.")
	expect_false(slide.fade, "Slide builder can disable opacity animation.")
	expect_equal(
		slide.get_hidden_position(Vector2(10.0, 20.0)),
		Vector2(34.0, 12.0),
		"Slide hidden position is relative to authored position.",
	)

	var pop := NucleusUITransitionProfile.pop(
		0.15,
		Vector2(0.9, 0.8),
	)
	var hidden_scale := pop.get_hidden_scale(Vector2(2.0, 3.0))
	expect_float(
		hidden_scale.x,
		1.8,
		"Pop hidden X scale is relative to authored scale.",
	)
	expect_float(
		hidden_scale.y,
		2.4,
		"Pop hidden Y scale is relative to authored scale.",
	)
	expect_equal(
		pop.get_hidden_scale(Vector2(2.0, 3.0), 0.0),
		Vector2(2.0, 3.0),
		"Zero motion amplitude removes nonessential scale displacement.",
	)


func _test_presenter_immediate_compatibility() -> void:
	var root := Control.new()
	var panel := Control.new()
	var presenter := NucleusUIPresenter.new()

	panel.scale = Vector2(1.5, 1.25)
	panel.modulate.a = 0.8
	panel.position = Vector2(12.0, 18.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	presenter.target = panel
	presenter.transition = NucleusUITransitionProfile.slide(
		Vector2(0.0, 24.0)
	)

	root.add_child(panel)
	root.add_child(presenter)

	expect_true(
		attach_test_node(root),
		"Presenter fixture requires a live SceneTree.",
	)

	presenter.hide_immediately()
	expect_false(panel.visible, "Immediate hide hides the target.")
	expect_equal(
		panel.scale,
		Vector2(1.5, 1.25),
		"Immediate hide restores authored scale.",
	)

	presenter.show_immediately()
	expect_true(panel.visible, "Immediate show restores visibility.")
	expect_equal(
		panel.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"Immediate show restores authored mouse filtering.",
	)

	free_test_node(root)


func _test_visual_state_math() -> void:
	var state := NucleusUIVisualStateProfile.new()
	state.scale_multiplier = Vector2(1.1, 0.9)
	state.offset = Vector2(12.0, -4.0)
	state.rotation_degrees = 10.0
	state.alpha_multiplier = 0.5

	var scaled := state.get_scale(Vector2(2.0, 2.0))
	expect_float(
		scaled.x,
		2.2,
		"Visual state X scale is relative to authored scale.",
	)
	expect_float(
		scaled.y,
		1.8,
		"Visual state Y scale is relative to authored scale.",
	)
	expect_equal(
		state.get_position(Vector2(4.0, 5.0), 0.5),
		Vector2(10.0, 3.0),
		"Reduced amplitude attenuates visual-state offset.",
	)
	expect_float(
		state.get_alpha(0.8),
		0.4,
		"Visual state opacity is relative to authored alpha.",
	)


func _test_progress_feedback_immediate() -> void:
	var root := Control.new()
	var primary := ProgressBar.new()
	var trailing := ProgressBar.new()
	var feedback := NucleusUIProgressFeedback.new()

	primary.min_value = 0.0
	primary.max_value = 200.0
	primary.value = 100.0
	trailing.min_value = 0.0
	trailing.max_value = 1.0
	trailing.value = 0.5

	root.add_child(primary)
	root.add_child(trailing)
	feedback.primary_target = primary
	feedback.trailing_target = trailing
	feedback.sync_trailing_bounds = false
	root.add_child(feedback)

	expect_true(
		attach_test_node(root),
		"Progress feedback fixture requires a live SceneTree.",
	)

	expect_equal(
		feedback.snap_to(50.0),
		OK,
		"Progress feedback accepts immediate values.",
	)
	expect_float(
		primary.value,
		50.0,
		"Primary Range receives the requested value.",
	)
	expect_float(
		trailing.value,
		0.25,
		"Trailing Range maps through normalized progress.",
	)
	expect_float(
		feedback.get_ratio(),
		0.25,
		"Progress feedback exposes normalized ratio.",
	)

	free_test_node(root)


func _test_interaction_selected_state() -> void:
	var root := Control.new()
	var button := Button.new()
	var feedback := NucleusUIInteractionFeedback.new()
	var profile := NucleusUIFeedbackProfile.new()
	var selected := NucleusUIVisualStateProfile.new()
	var motion := NucleusUIMotionProfile.new()

	button.scale = Vector2(2.0, 2.0)
	motion.respect_reduced_motion = false
	profile.motion = motion
	selected.scale_multiplier = Vector2(1.1, 1.1)
	profile.selected_state = selected
	feedback.target = button
	feedback.profile = profile

	root.add_child(button)
	root.add_child(feedback)

	expect_true(
		attach_test_node(root),
		"Interaction feedback fixture requires a live SceneTree.",
	)

	feedback.set_selected(true, false)
	expect_true(
		feedback.is_selected(),
		"Interaction feedback exposes explicit selected state.",
	)
	expect_float(
		button.scale.x,
		2.2,
		"Selected visual state updates X scale.",
	)
	expect_float(
		button.scale.y,
		2.2,
		"Selected visual state updates Y scale.",
	)

	feedback.reset_immediately()
	expect_equal(
		button.scale,
		Vector2(2.0, 2.0),
		"Reset restores the authored scale.",
	)

	free_test_node(root)


func _test_input_glyph_profile_resolution() -> void:
	var profile := NucleusInputGlyphProfile.new()
	var event := InputEventJoypadButton.new()
	var generic_entry := NucleusInputGlyphEntry.new()
	var xbox_entry := NucleusInputGlyphEntry.new()
	var generic_texture := ImageTexture.new()
	var xbox_texture := ImageTexture.new()

	event.button_index = 1
	var key := NucleusInputGlyphProfile.event_key(event)

	expect_false(
		key == &"",
		"Gamepad button bindings produce a stable glyph key.",
	)

	generic_entry.event_key = key
	generic_entry.texture = generic_texture
	profile.generic_gamepad.append(generic_entry)

	expect_true(
		profile.resolve_event(
			event,
			NucleusInputTypes.GamepadFamily.XBOX,
		) == generic_texture,
		"Family lookup falls back to the generic gamepad glyph.",
	)

	xbox_entry.event_key = key
	xbox_entry.texture = xbox_texture
	profile.xbox_gamepad.append(xbox_entry)

	expect_true(
		profile.resolve_event(
			event,
			NucleusInputTypes.GamepadFamily.XBOX,
		) == xbox_texture,
		"Family-specific glyphs override the generic gamepad fallback.",
	)


func _test_shader_effect_value_contract() -> void:
	expect_true(
		NucleusUIShaderEffect.is_interpolatable_value(0.5),
		"Shader effects accept float uniforms.",
	)
	expect_true(
		NucleusUIShaderEffect.is_interpolatable_value(
			Color(1.0, 0.5, 0.25)
		),
		"Shader effects accept Color uniforms.",
	)
	expect_false(
		NucleusUIShaderEffect.is_interpolatable_value("not interpolatable"),
		"Shader effects reject string uniforms for Tween interpolation.",
	)


func _test_typewriter_immediate_and_skip() -> void:
	var root := Control.new()
	var label := RichTextLabel.new()
	var typewriter := NucleusUITypewriter.new()

	label.text = "Nucleus"
	typewriter.target = label
	typewriter.respect_reduced_motion = false

	root.add_child(label)
	root.add_child(typewriter)

	expect_true(
		attach_test_node(root),
		"Typewriter fixture requires a live SceneTree.",
	)

	expect_equal(
		typewriter.reset(),
		OK,
		"Typewriter can reset an attached RichTextLabel.",
	)
	expect_equal(
		label.visible_characters,
		0,
		"Reset hides parsed text.",
	)

	expect_equal(
		typewriter.restart(),
		OK,
		"Typewriter can start a new reveal.",
	)
	expect_true(
		typewriter.is_revealing(),
		"Restart enters revealing state.",
	)

	typewriter.skip()
	expect_false(
		typewriter.is_revealing(),
		"Skip finishes the reveal.",
	)
	expect_equal(
		label.visible_characters,
		label.get_total_character_count(),
		"Skip exposes every parsed character.",
	)
	expect_float(
		typewriter.get_progress(),
		1.0,
		"Finished text reports full progress.",
	)

	free_test_node(root)


func _test_typewriter_punctuation_cadence() -> void:
	var root := Control.new()
	var label := RichTextLabel.new()
	var typewriter := NucleusUITypewriter.new()

	label.bbcode_enabled = true
	label.text = "[b]A,[/b]B"
	typewriter.target = label
	typewriter.characters_per_second = 100.0
	typewriter.minor_punctuation_delay = 0.5
	typewriter.major_punctuation_delay = 0.75
	typewriter.respect_reduced_motion = false
	typewriter.ignore_time_scale = false

	root.add_child(label)
	root.add_child(typewriter)

	expect_true(
		attach_test_node(root),
		"Typewriter cadence fixture requires a live SceneTree.",
	)

	expect_equal(
		typewriter.restart(),
		OK,
		"Typewriter cadence can start from BBCode text.",
	)

	typewriter._process(0.021)
	expect_equal(
		label.visible_characters,
		2,
		"Parsed punctuation becomes visible before its cadence pause.",
	)

	typewriter._process(0.25)
	expect_equal(
		label.visible_characters,
		2,
		"Minor punctuation holds the next character during the pause.",
	)

	typewriter._process(0.26)
	expect_equal(
		label.visible_characters,
		label.get_total_character_count(),
		"Reveal resumes after consuming the remaining punctuation pause.",
	)

	free_test_node(root)


func _test_typewriter_button_replay_and_skip() -> void:
	var root := Control.new()
	var label := RichTextLabel.new()
	var typewriter := NucleusUITypewriter.new()
	var replay := Button.new()
	var skip := Button.new()

	label.text = "Replay integration"
	typewriter.target = label
	typewriter.respect_reduced_motion = false
	typewriter.ignore_time_scale = false

	root.add_child(label)
	root.add_child(typewriter)
	root.add_child(replay)
	root.add_child(skip)

	expect_true(
		attach_test_node(root),
		"Typewriter button fixture requires a live SceneTree.",
	)

	replay.pressed.connect(typewriter.restart)
	skip.pressed.connect(typewriter.skip)

	typewriter.reveal_immediately()
	replay.emit_signal(&"pressed")
	expect_true(
		typewriter.is_revealing(),
		"A Button pressed signal can restart typewriter presentation.",
	)
	expect_equal(
		label.visible_characters,
		0,
		"Replay starts again from zero visible characters.",
	)

	typewriter._process(0.2)
	skip.emit_signal(&"pressed")
	expect_false(
		typewriter.is_revealing(),
		"A Button pressed signal can skip an active reveal.",
	)
	expect_equal(
		label.visible_characters,
		label.get_total_character_count(),
		"Button-driven skip exposes all remaining characters.",
	)

	free_test_node(root)


func _test_typewriter_skip_after_reset() -> void:
	var root := Control.new()
	var label := RichTextLabel.new()
	var typewriter := NucleusUITypewriter.new()

	label.text = "Reset then skip"
	typewriter.target = label
	typewriter.respect_reduced_motion = false

	root.add_child(label)
	root.add_child(typewriter)

	expect_true(
		attach_test_node(root),
		"Typewriter reset fixture requires a live SceneTree.",
	)

	typewriter.reset()
	expect_false(
		typewriter.is_revealing(),
		"Reset keeps the typewriter idle.",
	)

	typewriter.skip()
	expect_equal(
		label.visible_characters,
		label.get_total_character_count(),
		"Skip can finish deliberately hidden text after reset.",
	)

	free_test_node(root)
