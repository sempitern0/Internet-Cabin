extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_transition_profile_builders()
	_test_transition_profile_validation()
	return finish()


func _test_transition_profile_builders() -> void:
	var fade := NucleusSceneTransitionProfile.fade()
	expect_equal(
		fade.mode,
		NucleusSceneTransitionProfile.Mode.FADE,
		"Fade builder selects fade mode.",
	)
	expect_equal(
		fade.color,
		Color.BLACK,
		"Fade builder defaults to black.",
	)

	var curtain := NucleusSceneTransitionProfile.curtain()
	expect_equal(
		curtain.mode,
		NucleusSceneTransitionProfile.Mode.CURTAIN,
		"Curtain builder selects curtain mode.",
	)
	expect_equal(
		curtain.curtain_axis,
		NucleusSceneTransitionProfile.CurtainAxis.HORIZONTAL,
		"Curtain builder defaults to horizontal closure.",
	)

	var flash := NucleusSceneTransitionProfile.flash()
	expect_equal(
		flash.mode,
		NucleusSceneTransitionProfile.Mode.FLASH,
		"Flash builder selects flash mode.",
	)
	expect_equal(
		flash.color,
		Color.WHITE,
		"Flash builder defaults to white.",
	)

	var tiled := NucleusSceneTransitionProfile.tiled()
	expect_equal(
		tiled.mode,
		NucleusSceneTransitionProfile.Mode.SHADER,
		"Tiled builder uses shader mode.",
	)
	expect_true(
		tiled.shader_parameters.has(&"tile_count"),
		"Tiled builder exposes tile count as a shader parameter.",
	)


func _test_transition_profile_validation() -> void:
	var profile := NucleusSceneTransitionProfile.new()
	expect_true(
		profile.get_validation_errors().is_empty(),
		"Default transition profile is valid.",
	)

	profile.presentation_timeout_seconds = 0.1
	profile.cover_duration = 0.2
	expect_false(
		profile.get_validation_errors().is_empty(),
		"Timeout must exceed the authored visual phase.",
	)

	profile.presentation_timeout_seconds = 1.0
	profile.cover_duration = 0.2
	profile.mode = NucleusSceneTransitionProfile.Mode.SHADER
	profile.shader_progress_parameter = &""
	expect_false(
		profile.get_validation_errors().is_empty(),
		"Shader mode requires a progress parameter.",
	)

	profile.shader_progress_parameter = &"progress"
	profile.overlay_scene = PackedScene.new()
	expect_false(
		profile.get_validation_errors().is_empty(),
		"Custom overlay scenes must be instantiable.",
	)
