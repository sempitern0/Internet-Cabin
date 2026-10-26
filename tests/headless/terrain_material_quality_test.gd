extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_heightmap_transform()
	_test_heightmap_prefilter_target()
	_test_resolution_policy()
	_test_pbr_layer_material()
	_test_material_quality_and_reuse()
	return finish()


func _test_heightmap_transform() -> void:
	var source := Image.create_empty(
		2,
		3,
		false,
		Image.FORMAT_RGBA8,
	)
	source.fill(Color.BLACK)
	source.set_pixel(0, 0, Color.RED)

	var rotated := NucleusTerrainHeightmapProcessor.transformed(
		source,
		1,
		false,
		false,
	)

	expect_true(
		rotated != null,
		"Heightmap transform should return an image.",
	)
	expect_equal(
		rotated.get_width(),
		3,
		"Clockwise rotation should swap image width.",
	)
	expect_equal(
		rotated.get_height(),
		2,
		"Clockwise rotation should swap image height.",
	)
	expect_true(
		rotated.get_pixel(2, 0).is_equal_approx(Color.RED),
		"Clockwise rotation should preserve deterministic pixel placement.",
	)


func _test_heightmap_prefilter_target() -> void:
	var target := (
		NucleusTerrainHeightmapProcessor.suggested_sample_limit(
			Vector2i(512, 256),
			63,
		)
	)

	expect_equal(
		target,
		Vector2i(64, 32),
		"Prefilter target should preserve source aspect ratio.",
	)

	var source := Image.create_empty(
		128,
		64,
		false,
		Image.FORMAT_RF,
	)
	source.fill(Color(0.5, 0.0, 0.0, 1.0))

	var filtered := (
		NucleusTerrainHeightmapProcessor.prefilter_for_resolution(
			source,
			31,
			true,
		)
	)

	expect_equal(
		Vector2i(
			filtered.get_width(),
			filtered.get_height(),
		),
		Vector2i(128, 64),
		"Restored prefilter should preserve original image dimensions.",
	)


func _test_resolution_policy() -> void:
	var policy := NucleusTerrainResolutionPolicy.new()
	policy.minimum_visual_resolution = 32
	policy.maximum_visual_resolution = 256
	policy.visual_resolution_step = 16
	policy.full_meters_per_cell = 2.5
	policy.reduced_meters_per_cell = 4.0
	policy.minimal_meters_per_cell = 6.0
	policy.collision_resolution_ratio = 0.5
	policy.minimum_collision_resolution = 16
	policy.maximum_collision_resolution = 128
	policy.collision_resolution_step = 8

	expect_equal(
		policy.resolve_visual_resolution(
			Vector2(600.0, 450.0),
			NucleusTerrainResolutionPolicy.Quality.FULL,
		),
		240,
		"Full quality should resolve from physical meters per cell.",
	)
	expect_equal(
		policy.resolve_visual_resolution(
			Vector2(600.0, 450.0),
			NucleusTerrainResolutionPolicy.Quality.REDUCED,
		),
		160,
		"Reduced quality should round up to the authored resolution step.",
	)
	expect_equal(
		policy.resolve_visual_resolution(
			Vector2(600.0, 450.0),
			NucleusTerrainResolutionPolicy.Quality.MINIMAL,
		),
		112,
		"Minimal quality should use the coarser meter budget.",
	)
	expect_equal(
		policy.resolve_collision_resolution(
			Vector2(600.0, 450.0),
			NucleusTerrainResolutionPolicy.Quality.FULL,
		),
		120,
		"Collision resolution should remain independently bounded.",
	)
	expect_true(
		policy.get_validation_errors().is_empty(),
		"A valid terrain resolution policy should report no errors.",
	)


func _test_pbr_layer_material() -> void:
	var layer := NucleusTerrainTextureLayer.new()
	layer.albedo = _solid_texture(Color.WHITE)
	layer.normal = _solid_texture(
		Color(0.5, 0.5, 1.0, 1.0)
	)
	layer.roughness_texture = _solid_texture(
		Color(0.6, 0.6, 0.6, 1.0)
	)
	layer.normal_strength = 0.4
	layer.roughness_texture_strength = 0.75

	var profile := NucleusTerrainMaterialProfile.new()
	profile.layers.append(layer)

	var surface_material := profile.create_material(
		-10.0,
		50.0,
	) as ShaderMaterial

	expect_true(
		surface_material != null,
		"Built-in terrain profile should create a ShaderMaterial.",
	)
	expect_equal(
		surface_material.get_shader_parameter("layer0_use_normal"),
		true,
		"Configured normal texture should reach the terrain shader.",
	)
	expect_equal(
		surface_material.get_shader_parameter(
			"layer0_use_roughness_texture"
		),
		true,
		"Configured roughness texture should reach the terrain shader.",
	)
	expect_float(
		float(
			surface_material.get_shader_parameter(
				"layer0_normal_strength"
			)
		),
		0.4,
		"Normal strength should remain layer-authored.",
	)


func _test_material_quality_and_reuse() -> void:
	var layer := NucleusTerrainTextureLayer.new()
	layer.albedo = _solid_texture(Color.WHITE)

	var profile := NucleusTerrainMaterialProfile.new()
	profile.projection_mode = 1
	profile.layers.append(layer)
	profile.reuse_generated_materials = true

	var full_a := profile.create_material(
		0.0,
		20.0,
		NucleusTerrainMaterialProfile.DebugView.MATERIAL,
		6,
		10.0,
		NucleusTerrainMaterialProfile.Quality.FULL,
	) as ShaderMaterial
	var full_b := profile.create_material(
		0.0,
		20.0,
		NucleusTerrainMaterialProfile.DebugView.MATERIAL,
		6,
		10.0,
		NucleusTerrainMaterialProfile.Quality.FULL,
	) as ShaderMaterial
	var minimal := profile.create_material(
		0.0,
		20.0,
		NucleusTerrainMaterialProfile.DebugView.MATERIAL,
		6,
		10.0,
		NucleusTerrainMaterialProfile.Quality.MINIMAL,
	) as ShaderMaterial

	expect_true(
		full_a == full_b,
		"Equivalent generated material requests should reuse one material.",
	)
	expect_equal(
		full_a.get_shader_parameter("use_triplanar"),
		true,
		"Full quality should preserve authored triplanar projection.",
	)
	expect_equal(
		full_a.get_shader_parameter("detail_enabled"),
		true,
		"Full quality should preserve PBR detail sampling.",
	)
	expect_equal(
		minimal.get_shader_parameter("use_triplanar"),
		false,
		"Minimal quality should default to cheaper top projection.",
	)
	expect_equal(
		minimal.get_shader_parameter("detail_enabled"),
		false,
		"Minimal quality should default to scalar PBR fallback.",
	)
	expect_equal(
		profile.get_cached_material_count(),
		2,
		"Distinct quality tiers should occupy distinct cache entries.",
	)

	profile.clear_material_cache()
	expect_equal(
		profile.get_cached_material_count(),
		0,
		"Generated terrain material cache should be explicitly clearable.",
	)


func _solid_texture(color: Color) -> ImageTexture:
	var image := Image.create_empty(
		2,
		2,
		false,
		Image.FORMAT_RGBA8,
	)
	image.fill(color)
	return ImageTexture.create_from_image(image)
