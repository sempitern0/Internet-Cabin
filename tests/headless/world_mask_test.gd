extends "res://tests/headless/test_case.gd"


class CountingTexture extends Texture2D:
	var image: Image
	var reads: int = 0

	func _get_image() -> Image:
		reads += 1
		return image

	func _get_width() -> int:
		return image.get_width() if image != null else 0

	func _get_height() -> int:
		return image.get_height() if image != null else 0


func run() -> Dictionary:
	_test_world_mapping_and_channels()
	_test_affine_transform()
	_test_cache_lifecycle()
	_test_footprint_and_failures()
	return finish()


func _fixture() -> CountingTexture:
	var source := CountingTexture.new()
	source.image = Image.create_empty(2, 2, false, Image.FORMAT_RGBAF)
	source.image.set_pixel(0, 0, Color(0.1, 0.2, 0.3, 0.4))
	source.image.set_pixel(1, 0, Color(0.5, 0.6, 0.7, 0.8))
	source.image.set_pixel(0, 1, Color(0.9, 0.8, 0.7, 0.6))
	source.image.set_pixel(1, 1, Color(1.0, 0.5, 0.0, 1.0))
	return source


func _test_world_mapping_and_channels() -> void:
	var mask := NucleusWorldMask3D.new()
	mask.texture = _fixture()
	mask.coverage_size = Vector2(4.0, 8.0)
	expect_equal(mask.local_to_uv(Vector3.ZERO), Vector2(0.5, 0.5),
		"Local center maps to UV center.")
	expect_equal(mask.local_to_uv(Vector3(-2.0, 5.0, -4.0)), Vector2.ZERO,
		"Mapping ignores local Y.")
	expect_float(mask.sample_world(Vector3(-2.0, 0.0, -4.0)), 0.1,
		"Negative corner reads the first texel.")
	expect_float(mask.sample_world(Vector3.ZERO), 1.0,
		"UV half-cell boundaries map to the positive-side texel.")
	expect_float(mask.sample_world(Vector3(2.0, 0.0, 4.0)), 1.0,
		"Positive outer boundary includes the last texel.")
	mask.channel = NucleusWorldMask3D.Channel.GREEN
	expect_float(mask.sample_world(Vector3(-1.0, 0.0, -1.0)), 0.2,
		"Green data channel is sampled.")
	mask.channel = NucleusWorldMask3D.Channel.LUMINANCE
	expect_float(mask.sample_world(Vector3(-1.0, 0.0, -1.0)), 0.18596,
		"Luminance uses stored channel values.")
	mask.inverse = true
	expect_float(mask.sample_world(Vector3(-1.0, 0.0, -1.0)), 0.81404,
		"Inverse applies to a valid sample.")
	mask.outside_value = 0.25
	expect_float(mask.sample_world(Vector3(2.01, 0.0, 0.0)), 0.25,
		"Outside fallback is not inverted.")
	mask.free()


func _test_affine_transform() -> void:
	var parent := Node3D.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(parent)
	parent.position = Vector3(100.0, 0.0, -50.0)
	parent.rotation.y = 0.5
	var mask := NucleusWorldMask3D.new()
	mask.texture = _fixture()
	mask.coverage_size = Vector2(4.0, 8.0)
	mask.position = Vector3(2.0, 0.0, 3.0)
	mask.scale = Vector3(2.0, 1.0, 3.0)
	parent.add_child(mask)
	var point: Vector3 = mask.global_transform * Vector3(-1.0, 9.0, -2.0)
	expect_true(mask.world_to_uv(point).is_equal_approx(Vector2(0.25, 0.25)),
		"World mapping includes hierarchy, rotation and nonuniform scale.")
	expect_float(mask.sample_world(point), 0.1,
		"World sampling uses the full affine inverse.")
	parent.free()


func _test_cache_lifecycle() -> void:
	var source := _fixture()
	var mask := NucleusWorldMask3D.new()
	mask.texture = source
	for index: int in range(128):
		mask.sample_world(Vector3.ZERO)
	expect_equal(source.reads, 1,
		"Repeated queries share one owned Image snapshot.")
	source.image.fill(Color(0.6, 0.0, 0.0))
	expect_float(mask.sample_world(Vector3.ZERO), 1.0,
		"Mutating source pixels without invalidation preserves the snapshot.")
	source.emit_changed()
	expect_float(mask.sample_world(Vector3.ZERO), 0.6,
		"Resource.changed triggers one cache refresh.")
	expect_equal(source.reads, 2,
		"Refreshing performs one new texture read.")
	mask.refresh_cache()
	expect_equal(source.reads, 3,
		"Explicit refresh supports sources without change notifications.")
	mask.texture = null
	expect_float(mask.sample_world(Vector3.ZERO), 0.0,
		"Clearing the texture clears the cached image.")
	mask.free()


func _test_footprint_and_failures() -> void:
	var source := _fixture()
	source.image.fill(Color.WHITE)
	var mask := NucleusWorldMask3D.new()
	mask.texture = source
	mask.coverage_size = Vector2(2.0, 2.0)
	expect_float(mask.sample_world_average(Vector3.ZERO, 0.8), 1.0,
		"A bounded footprint inside the mask reads its coverage.")
	expect_float(mask.sample_world_average(Vector3.ZERO, 2.0), 1.0 / 9.0,
		"Outside ring samples participate via the fallback.")
	mask.coverage_size = Vector2(0.0, 1.0)
	expect_false(mask.local_to_uv(Vector3.ZERO).is_finite(),
		"Invalid coverage must not produce plausible UVs.")
	expect_float(mask.sample_world(Vector3.ZERO), 0.0,
		"Invalid coverage falls back safely.")
	mask.coverage_size = Vector2.ONE
	expect_float(mask.sample_world(Vector3(NAN, 0.0, 0.0)), 0.0,
		"Nonfinite world coordinates are rejected.")
	expect_float(mask.sample_world_average(Vector3.ZERO, INF), 0.0,
		"Nonfinite footprint radius is rejected.")
	mask.transform = Transform3D(
		Basis(Vector3.ZERO, Vector3.UP, Vector3.BACK), Vector3.ZERO)
	expect_false(mask.world_to_uv(Vector3.ZERO).is_finite(),
		"A noninvertible transform must not be inverted.")
	mask.free()
