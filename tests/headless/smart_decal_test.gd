extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_cardinal_surface_basis()
	_test_curved_surface_basis()
	_test_tangent_hint()
	_test_invalid_surface_normal()
	_test_configuration_warning()
	return finish()


func _test_cardinal_surface_basis() -> void:
	var up_basis := NucleusSmartDecal3D.build_surface_basis(Vector3.UP)
	var down_basis := NucleusSmartDecal3D.build_surface_basis(Vector3.DOWN)

	expect_true(
		up_basis.y.is_equal_approx(Vector3.UP),
		"Up-facing surface should map to decal local +Y.",
	)
	expect_true(
		down_basis.y.is_equal_approx(Vector3.DOWN),
		"Down-facing surface should map to decal local +Y.",
	)
	expect_float(
		up_basis.determinant(),
		1.0,
		"Surface basis should remain orthonormal and right-handed.",
	)


func _test_curved_surface_basis() -> void:
	var normal := Vector3(1.0, 2.0, -3.0).normalized()
	var basis := NucleusSmartDecal3D.build_surface_basis(normal)

	expect_true(
		basis.y.is_equal_approx(normal),
		"Arbitrary curved-surface normals should be preserved.",
	)
	expect_float(
		basis.x.dot(basis.y),
		0.0,
		"Surface tangent should remain perpendicular to the normal.",
	)
	expect_float(
		basis.z.dot(basis.y),
		0.0,
		"Surface bitangent should remain perpendicular to the normal.",
	)


func _test_tangent_hint() -> void:
	var basis := NucleusSmartDecal3D.build_surface_basis(
		Vector3.UP,
		Vector3.RIGHT,
	)

	expect_true(
		basis.x.is_equal_approx(Vector3.RIGHT),
		"Tangent hint should control decal planar orientation.",
	)


func _test_invalid_surface_normal() -> void:
	var decal := NucleusSmartDecal3D.new()
	var error: Error = decal.place_on_surface(
		Vector3.ZERO,
		Vector3.ZERO,
	)

	expect_equal(
		error,
		ERR_INVALID_PARAMETER,
		"Zero surface normal should be rejected.",
	)
	decal.free()


func _test_configuration_warning() -> void:
	var decal := NucleusSmartDecal3D.new()

	expect_true(
		not decal._get_configuration_warnings().is_empty(),
		"A textureless SmartDecal should report an editor warning.",
	)
	decal.free()
