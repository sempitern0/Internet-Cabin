extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_stamp_lifetime_and_motion()
	_test_capacity_is_bounded()
	_test_world_mapping_survives_recentering()
	_test_motion_emission_is_distance_based()
	_test_motion_breaks_on_teleport()
	return finish()


func _test_stamp_lifetime_and_motion() -> void:
	var buffer := NucleusWorldStampBuffer3D.new()
	buffer.auto_advance = false
	var stamp := buffer.emit_stamp(
		Vector3(2.0, 0.0, 3.0),
		Vector2(2.0, 1.0),
		0.0,
		0.8,
		2.0,
		Vector3(1.0, 0.0, 0.0),
		Vector2(1.0, 0.5),
	)

	expect_true(stamp != null, "In-bounds stamp should be accepted.")
	expect_equal(buffer.get_active_count(), 1, "Fresh stamp should be active.")

	buffer.advance(1.0)
	expect_true(
		stamp.get_world_position(buffer.elapsed_time).is_equal_approx(
			Vector3(3.0, 0.0, 3.0)
		),
		"Stamp drift should be evaluated from world-space age.",
	)
	expect_true(
		stamp.get_dimensions(buffer.elapsed_time).is_equal_approx(
			Vector2(3.0, 1.25)
		),
		"Stamp growth should scale dimensions over normalized lifetime.",
	)

	buffer.advance(1.1)
	expect_equal(buffer.get_active_count(), 0, "Expired stamp should become inactive.")
	buffer.free()


func _test_capacity_is_bounded() -> void:
	var buffer := NucleusWorldStampBuffer3D.new()
	buffer.max_stamps = 2
	buffer.emit_stamp(Vector3.ZERO)
	buffer.emit_stamp(Vector3(1.0, 0.0, 0.0))
	buffer.emit_stamp(Vector3(2.0, 0.0, 0.0))

	expect_equal(
		buffer.get_stored_count(),
		2,
		"Stamp storage should never exceed configured capacity.",
	)
	expect_equal(
		buffer.get_active_count(),
		2,
		"Replacing a full slot should keep capacity fully usable.",
	)
	buffer.free()


func _test_world_mapping_survives_recentering() -> void:
	var buffer := NucleusWorldStampBuffer3D.new()
	buffer.coverage_size = Vector2(20.0, 20.0)
	var stamp := buffer.emit_stamp(Vector3(5.0, 0.0, 0.0))

	expect_true(
		buffer.world_to_uv(stamp.world_position).is_equal_approx(
			Vector2(0.75, 0.5)
		),
		"World-to-UV mapping should use the current world-space center.",
	)

	buffer.set_center(Vector3(5.0, 0.0, 0.0))
	expect_true(
		buffer.world_to_uv(stamp.world_position).is_equal_approx(
			Vector2(0.5, 0.5)
		),
		"Recentering should reproject history instead of moving stamp data.",
	)
	expect_true(
		stamp.world_position.is_equal_approx(Vector3(5.0, 0.0, 0.0)),
		"Recentering must not mutate stored world-space stamp positions.",
	)
	buffer.free()


func _test_motion_emission_is_distance_based() -> void:
	var buffer := NucleusWorldStampBuffer3D.new()
	buffer.motion_spacing = 0.5
	buffer.max_motion_stamps_per_call = 8

	expect_equal(
		buffer.emit_motion(7, Vector3.ZERO),
		0,
		"First motion sample should initialize emitter history only.",
	)
	expect_equal(
		buffer.emit_motion(7, Vector3(2.0, 0.0, 0.0)),
		4,
		"Motion stamps should depend on distance traveled, not frame count.",
	)
	expect_equal(buffer.get_active_count(), 4, "Motion should create four stamps.")
	buffer.free()


func _test_motion_breaks_on_teleport() -> void:
	var buffer := NucleusWorldStampBuffer3D.new()
	buffer.coverage_size = Vector2(40.0, 40.0)
	buffer.motion_break_distance_ratio = 0.25
	buffer.emit_motion(3, Vector3.ZERO)

	expect_equal(
		buffer.emit_motion(3, Vector3(15.0, 0.0, 0.0)),
		0,
		"Large motion jumps should reset history instead of drawing a long stripe.",
	)
	expect_equal(
		buffer.get_active_count(),
		0,
		"Teleport reset should not create intermediate visual stamps.",
	)
	buffer.free()
