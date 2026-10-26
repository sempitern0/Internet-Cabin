extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_texture_audit_import_settings()
	_test_material_instance_value_contract()
	_test_material_quality_restores_authored_override()
	_test_geometry_quality_restores_authored_state()
	_test_render_audit_shader_material_variants()
	return finish()


func _test_texture_audit_import_settings() -> void:
	var profile := NucleusTextureBudgetProfile.new()
	profile.warning_dimension = 1024
	profile.critical_dimension = 2048

	var diagnostics := NucleusTextureAudit.inspect_import_settings(
		"res://assets/rock_normal.png",
		4096,
		4096,
		{
			"mipmaps/generate": false,
			"compress/mode": NucleusTextureAudit.COMPRESS_LOSSLESS,
			"compress/normal_map":
				NucleusTextureAudit.NORMAL_MAP_DISABLED,
		},
		profile,
		true,
	)

	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"texture_audit_critical_dimensions",
		),
		"Texture audit should flag dimensions beyond the critical threshold.",
	)
	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"texture_audit_missing_mipmaps_3d",
		),
		"Texture audit should flag missing 3D mipmaps.",
	)
	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"texture_audit_non_vram_compressed_3d",
		),
		"Texture audit should flag high-memory 3D compression modes.",
	)
	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"texture_audit_normal_map_detection_disabled",
		),
		"Texture audit should review normal-looking files with detection disabled.",
	)

	expect_equal(
		NucleusTextureAudit.estimate_rgba8_bytes(
			1024,
			1024,
			false,
		),
		4194304,
		"RGBA8 baseline estimate should use four bytes per texel.",
	)


func _test_material_instance_value_contract() -> void:
	expect_true(
		NucleusMaterialInstanceBinding3D.is_supported_instance_value(
			Color.WHITE
		),
		"Per-instance binding should accept shader vector/color values.",
	)
	expect_true(
		NucleusMaterialInstanceBinding3D.is_supported_instance_value(
			Vector3.ONE
		),
		"Per-instance binding should accept vector values.",
	)
	expect_false(
		NucleusMaterialInstanceBinding3D.is_supported_instance_value(
			ImageTexture.new()
		),
		"Per-instance binding should reject texture objects.",
	)

	var binding := NucleusMaterialInstanceBinding3D.new()
	expect_equal(
		binding.set_parameter(&"tint", Color.WHITE),
		ERR_UNCONFIGURED,
		"Per-instance binding should reject writes without a target.",
	)
	binding.free()


func _test_material_quality_restores_authored_override() -> void:
	var root := Node3D.new()
	var target := MeshInstance3D.new()
	target.mesh = BoxMesh.new()

	var authored := StandardMaterial3D.new()
	var minimal := StandardMaterial3D.new()
	target.material_override = authored

	var profile := NucleusMaterialQualityProfile3D.new()
	profile.minimal_material_override = minimal

	var controller := NucleusMaterialQualityController3D.new()
	controller.target = target
	controller.profile = profile
	controller.quality = NucleusMaterialQualityProfile3D.Quality.MINIMAL

	root.add_child(target)
	root.add_child(controller)

	expect_true(
		attach_test_node(root),
		"Material-quality fixture requires a live SceneTree.",
	)
	expect_true(
		target.material_override == minimal,
		"Minimal quality should apply its configured material override.",
	)

	controller.set_quality(
		NucleusMaterialQualityProfile3D.Quality.FULL
	)
	expect_true(
		target.material_override == authored,
		"A null Full override should restore authored material state.",
	)

	free_test_node(root)


func _test_geometry_quality_restores_authored_state() -> void:
	var root := Node3D.new()
	var target := MeshInstance3D.new()
	target.mesh = BoxMesh.new()
	target.lod_bias = 1.2
	target.visibility_range_end = 100.0
	target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var profile := NucleusGeometryQualityProfile3D.new()
	profile.minimal_lod_bias_scale = 0.5
	profile.minimal_visibility_end_cap = 40.0
	profile.disable_shadows_in_minimal = true

	var controller := NucleusGeometryQualityController3D.new()
	controller.target = target
	controller.profile = profile
	controller.quality = NucleusGeometryQualityProfile3D.Quality.MINIMAL

	root.add_child(target)
	root.add_child(controller)

	expect_true(
		attach_test_node(root),
		"Geometry-quality fixture requires a live SceneTree.",
	)
	expect_float(
		target.lod_bias,
		0.6,
		"Minimal quality should scale the authored native LOD bias.",
	)
	expect_float(
		target.visibility_range_end,
		40.0,
		"Minimal quality should cap native visibility range when configured.",
	)
	expect_equal(
		target.cast_shadow,
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"Minimal quality should disable shadows when configured.",
	)

	controller.set_quality(
		NucleusGeometryQualityProfile3D.Quality.FULL
	)
	expect_float(
		target.lod_bias,
		1.2,
		"Full quality should restore authored LOD bias.",
	)
	expect_float(
		target.visibility_range_end,
		100.0,
		"Full quality should restore authored visibility range.",
	)
	expect_equal(
		target.cast_shadow,
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"Full quality should restore authored shadow policy.",
	)

	free_test_node(root)


func _test_render_audit_shader_material_variants() -> void:
	var root := Node3D.new()
	var shared_shader := Shader.new()
	shared_shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(1.0); }"

	for index: int in range(3):
		var instance := MeshInstance3D.new()
		instance.mesh = BoxMesh.new()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 100.0

		var material := ShaderMaterial.new()
		material.shader = shared_shader
		instance.material_override = material
		root.add_child(instance)

	var diagnostics := NucleusRenderAudit.inspect(
		root,
		99,
		99,
		99,
		3,
		99,
	)

	expect_true(
		_has_diagnostic_code(
			diagnostics,
			&"render_audit_shader_material_variants",
		),
		"Render audit should flag many ShaderMaterial variants sharing one Shader.",
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
