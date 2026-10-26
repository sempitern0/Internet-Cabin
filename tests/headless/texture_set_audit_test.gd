extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_pbr_package_redundancy()
	_test_texture_set_classification()
	return finish()


func _test_pbr_package_redundancy() -> void:
	var diagnostics := NucleusTextureSetAudit.inspect_paths(
		PackedStringArray([
			"res://rock_1k_NormalGL.jpg",
			"res://rock_1k_NormalDX.jpg",
			"res://rock_1k_Roughness.jpg",
			"res://rock_1k_AO.jpg",
			"res://rock_1k_ARM.jpg",
			"res://rock_1k_Displacement.jpg",
		])
	)

	expect_true(
		_has_code(
			diagnostics,
			&"texture_set_dual_normal_convention",
		),
		"Texture-set audit should identify dual GL/DX normal variants.",
	)
	expect_true(
		_has_code(
			diagnostics,
			&"texture_set_packed_roughness_overlap",
		),
		"Texture-set audit should identify packed/standalone roughness overlap.",
	)
	expect_true(
		_has_code(
			diagnostics,
			&"texture_set_packed_ao_overlap",
		),
		"Texture-set audit should identify packed/standalone AO overlap.",
	)
	expect_true(
		_has_code(
			diagnostics,
			&"texture_set_height_detail_review",
		),
		"Texture-set audit should flag optional displacement/height data.",
	)


func _test_texture_set_classification() -> void:
	var classification := NucleusTextureSetAudit.classify_path(
		"res://Grass001_1K-JPG_NormalGL.jpg"
	)

	expect_equal(
		String(classification["set_key"]),
		"grass001_1k_jpg",
		"Texture-set classifier should preserve the common vendor-set stem.",
	)
	expect_equal(
		StringName(classification["type"]),
		NucleusTextureSetAudit.TYPE_NORMAL_GL,
		"Texture-set classifier should recognize NormalGL convention.",
	)

	var packed := NucleusTextureSetAudit.classify_path(
		"res://brown_mud_leaves_01_arm_1k.jpg"
	)
	expect_equal(
		String(packed["set_key"]),
		"brown_mud_leaves_01_1k",
		"Trailing resolution tokens should remain part of the texture-set key.",
	)
	expect_equal(
		StringName(packed["type"]),
		NucleusTextureSetAudit.TYPE_ARM,
		"Trailing resolution tokens should not hide packed ARM classification.",
	)


func _has_code(
	diagnostics: Array[NucleusPerformanceDiagnostic],
	code: StringName,
) -> bool:
	for diagnostic: NucleusPerformanceDiagnostic in diagnostics:
		if diagnostic.code == code:
			return true

	return false
