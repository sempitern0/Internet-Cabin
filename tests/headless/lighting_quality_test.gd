extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_light_profile_defaults()
	_test_omni_quality_restores_authored_state()
	_test_directional_quality_uses_native_modes()
	_test_viewport_shadow_quality_restores_authored_state()
	_test_lighting_audit()
	return finish()


func _test_light_profile_defaults() -> void:
	var profile: NucleusLightQualityProfile3D = (
		NucleusLightQualityProfile3D.new()
	)

	expect_equal(
		profile.get_omni_shadow_mode(
			NucleusLightQualityProfile3D.Quality.MINIMAL
		),
		OmniLight3D.SHADOW_DUAL_PARABOLOID,
		"Minimal lighting uses the cheaper native omni shadow mode.",
	)
	expect_equal(
		profile.get_directional_shadow_mode(
			NucleusLightQualityProfile3D.Quality.MINIMAL
		),
		DirectionalLight3D.SHADOW_ORTHOGONAL,
		"Minimal lighting uses the cheapest directional shadow mode.",
	)
	expect_true(
		profile.should_disable_shadows(
			NucleusLightQualityProfile3D.Quality.MINIMAL
		),
		"Minimal profile can disable shadows when the controller owns that gate.",
	)


func _test_omni_quality_restores_authored_state() -> void:
	var root: Node3D = Node3D.new()
	var light: OmniLight3D = OmniLight3D.new()
	var controller: NucleusLightQualityController3D = (
		NucleusLightQualityController3D.new()
	)
	var profile: NucleusLightQualityProfile3D = (
		NucleusLightQualityProfile3D.new()
	)
	var projector: ImageTexture = ImageTexture.new()

	light.shadow_enabled = true
	light.shadow_blur = 2.0
	light.light_size = 1.0
	light.light_volumetric_fog_energy = 1.0
	light.light_projector = projector
	light.distance_fade_enabled = true
	light.distance_fade_begin = 80.0
	light.distance_fade_length = 20.0
	light.distance_fade_shadow = 50.0
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE

	controller.profile = profile
	controller.quality = NucleusLightQualityProfile3D.Quality.MINIMAL
	light.add_child(controller)
	root.add_child(light)

	expect_true(
		attach_test_node(root),
		"Omni light-quality fixture requires a live SceneTree.",
	)
	expect_true(
		light.shadow_enabled,
		"Shadow-enabled ownership is opt-in and does not fight another owner.",
	)
	expect_float(
		light.shadow_blur,
		1.0,
		"Minimal quality scales native shadow blur.",
	)
	expect_float(
		light.light_size,
		0.0,
		"Minimal quality can remove expensive source-size softness.",
	)
	expect_float(
		light.distance_fade_begin,
		40.0,
		"Minimal quality scales authored native distance fade.",
	)
	expect_float(
		light.distance_fade_length,
		10.0,
		"Minimal quality shortens the authored fade interval.",
	)
	expect_float(
		light.distance_fade_shadow,
		17.5,
		"Minimal quality cuts local shadows before the light fade.",
	)
	expect_equal(
		light.omni_shadow_mode,
		OmniLight3D.SHADOW_DUAL_PARABOLOID,
		"Minimal quality uses dual-paraboloid omni shadows.",
	)
	expect_true(
		light.light_projector == null,
		"Minimal quality can remove decorative projector sampling.",
	)
	expect_float(
		light.light_volumetric_fog_energy,
		0.0,
		"Minimal quality can remove per-light volumetric fog cost.",
	)

	controller.manage_shadow_enabled = true
	expect_false(
		light.shadow_enabled,
		"Explicit shadow ownership lets minimal quality disable the shadow.",
	)

	controller.set_quality(NucleusLightQualityProfile3D.Quality.FULL)
	expect_true(
		light.shadow_enabled,
		"Full quality restores the authored shadow-enabled state.",
	)
	expect_float(
		light.shadow_blur,
		2.0,
		"Full quality restores authored shadow blur.",
	)
	expect_float(
		light.light_size,
		1.0,
		"Full quality restores authored light size.",
	)
	expect_float(
		light.distance_fade_begin,
		80.0,
		"Full quality restores authored fade distance.",
	)
	expect_equal(
		light.omni_shadow_mode,
		OmniLight3D.SHADOW_CUBE,
		"Full quality restores authored cubemap shadows.",
	)
	expect_true(
		light.light_projector == projector,
		"Full quality restores the authored projector.",
	)

	free_test_node(root)


func _test_directional_quality_uses_native_modes() -> void:
	var root: Node3D = Node3D.new()
	var light: DirectionalLight3D = DirectionalLight3D.new()
	var controller: NucleusLightQualityController3D = (
		NucleusLightQualityController3D.new()
	)
	var profile: NucleusLightQualityProfile3D = (
		NucleusLightQualityProfile3D.new()
	)

	light.shadow_enabled = true
	light.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	)
	light.directional_shadow_max_distance = 200.0
	light.directional_shadow_blend_splits = true
	light.light_angular_distance = 0.5

	controller.profile = profile
	controller.quality = NucleusLightQualityProfile3D.Quality.REDUCED
	light.add_child(controller)
	root.add_child(light)

	expect_true(
		attach_test_node(root),
		"Directional light-quality fixture requires a live SceneTree.",
	)
	expect_equal(
		light.directional_shadow_mode,
		DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"Reduced quality uses the native 2-split directional mode.",
	)
	expect_float(
		light.directional_shadow_max_distance,
		130.0,
		"Reduced quality shortens directional shadow distance.",
	)
	expect_float(
		light.light_angular_distance,
		0.25,
		"Reduced quality scales directional PCSS angular size.",
	)
	expect_true(
		light.directional_shadow_blend_splits,
		"Reduced quality preserves authored split blending by default.",
	)

	controller.set_quality(NucleusLightQualityProfile3D.Quality.MINIMAL)
	expect_equal(
		light.directional_shadow_mode,
		DirectionalLight3D.SHADOW_ORTHOGONAL,
		"Minimal quality uses the native orthogonal directional mode.",
	)
	expect_float(
		light.directional_shadow_max_distance,
		70.0,
		"Minimal quality aggressively shortens directional shadow distance.",
	)
	expect_float(
		light.light_angular_distance,
		0.0,
		"Minimal quality removes directional PCSS by default.",
	)
	expect_false(
		light.directional_shadow_blend_splits,
		"Minimal quality removes split blending work.",
	)

	controller.set_quality(NucleusLightQualityProfile3D.Quality.FULL)
	expect_equal(
		light.directional_shadow_mode,
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"Full quality restores authored directional shadow mode.",
	)
	expect_float(
		light.directional_shadow_max_distance,
		200.0,
		"Full quality restores authored directional shadow range.",
	)
	expect_float(
		light.light_angular_distance,
		0.5,
		"Full quality restores authored directional softness.",
	)

	free_test_node(root)


func _test_viewport_shadow_quality_restores_authored_state() -> void:
	var root: Node = Node.new()
	var viewport: SubViewport = SubViewport.new()
	var controller: NucleusViewportShadowQualityController3D = (
		NucleusViewportShadowQualityController3D.new()
	)
	var profile: NucleusViewportShadowQualityProfile3D = (
		NucleusViewportShadowQualityProfile3D.new()
	)

	viewport.positional_shadow_atlas_size = 4096
	viewport.positional_shadow_atlas_16_bits = false
	viewport.set_positional_shadow_atlas_quadrant_subdiv(
		0,
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1,
	)
	viewport.set_positional_shadow_atlas_quadrant_subdiv(
		1,
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4,
	)
	viewport.set_positional_shadow_atlas_quadrant_subdiv(
		2,
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16,
	)
	viewport.set_positional_shadow_atlas_quadrant_subdiv(
		3,
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64,
	)

	controller.target_viewport = viewport
	controller.profile = profile
	controller.quality = (
		NucleusViewportShadowQualityProfile3D.Quality.MINIMAL
	)

	root.add_child(viewport)
	root.add_child(controller)

	expect_true(
		attach_test_node(root),
		"Viewport shadow-quality fixture requires a live SceneTree.",
	)
	expect_equal(
		viewport.positional_shadow_atlas_size,
		1024,
		"Minimal quality applies its native positional shadow atlas size.",
	)
	expect_true(
		viewport.positional_shadow_atlas_16_bits,
		"Minimal quality can use lower-cost 16-bit positional depth.",
	)
	expect_equal(
		viewport.get_positional_shadow_atlas_quadrant_subdiv(0),
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16,
		"Minimal quality applies its authored first atlas quadrant.",
	)
	expect_equal(
		viewport.get_positional_shadow_atlas_quadrant_subdiv(3),
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_256,
		"Minimal quality can trade resolution for more low-cost shadow slots.",
	)

	controller.set_quality(
		NucleusViewportShadowQualityProfile3D.Quality.FULL
	)
	expect_equal(
		viewport.positional_shadow_atlas_size,
		4096,
		"Full quality restores the authored atlas size.",
	)
	expect_false(
		viewport.positional_shadow_atlas_16_bits,
		"Full quality restores authored depth precision.",
	)
	expect_equal(
		viewport.get_positional_shadow_atlas_quadrant_subdiv(0),
		Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1,
		"Full quality restores authored quadrant subdivision.",
	)

	free_test_node(root)


func _test_lighting_audit() -> void:
	var root: Node3D = Node3D.new()
	var omni: OmniLight3D = OmniLight3D.new()
	var spot: SpotLight3D = SpotLight3D.new()
	var area: AreaLight3D = AreaLight3D.new()
	var directional: DirectionalLight3D = DirectionalLight3D.new()

	omni.shadow_enabled = true
	omni.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	omni.distance_fade_enabled = false
	omni.light_size = 0.5

	spot.shadow_enabled = true
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 20.0
	spot.distance_fade_length = 10.0
	spot.distance_fade_shadow = 30.0

	area.shadow_enabled = true
	area.light_size = 0.5

	directional.shadow_enabled = true
	directional.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	)
	directional.directional_shadow_max_distance = 200.0
	directional.directional_shadow_blend_splits = true
	directional.light_angular_distance = 0.5

	root.add_child(omni)
	root.add_child(spot)
	root.add_child(area)
	root.add_child(directional)

	var diagnostics: Array[NucleusPerformanceDiagnostic] = (
		NucleusLightingAudit3D.inspect(
			root,
			null,
			1,
			1,
			1,
			1,
			1,
			99,
			150.0,
		)
	)

	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"lighting_audit_shadowed_local_lights",
		),
		"Lighting audit reports local real-time shadow pressure.",
	)
	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"lighting_audit_local_lights_without_distance_fade",
		),
		"Lighting audit reports local lights without native distance fade.",
	)
	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"lighting_audit_late_shadow_cutoff",
		),
		"Lighting audit reports shadows that persist until the light fade ends.",
	)
	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"lighting_audit_omni_cube_shadows",
		),
		"Lighting audit reports cubemap omni shadow pressure.",
	)
	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"lighting_audit_area_light_pressure",
		),
		"Lighting audit reports AreaLight3D pressure.",
	)
	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"lighting_audit_directional_shadow_quality",
		),
		"Lighting audit reports expensive directional shadow features.",
	)

	root.free()


func _has_diagnostic_code(
	diagnostics: Array[NucleusPerformanceDiagnostic],
	code: StringName,
) -> bool:
	for diagnostic: NucleusPerformanceDiagnostic in diagnostics:
		if diagnostic.code == code:
			return true

	return false
