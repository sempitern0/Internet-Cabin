extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var regenerator := NucleusRegenerator.new()
	expect_true(
		not regenerator._get_configuration_warnings().is_empty(),
		"Regenerator warns when no ValuePool can be resolved.",
	)

	var pool := NucleusValuePool.new()
	pool.add_child(regenerator)
	expect_true(
		regenerator._get_configuration_warnings().is_empty(),
		"Regenerator accepts a parent ValuePool as valid auto-wiring.",
	)
	pool.free()

	var sensor := NucleusTargetAreaSensor2D.new()
	var initial_warnings := sensor._get_configuration_warnings()
	expect_true(
		initial_warnings.size() >= 2,
		"TargetAreaSensor2D warns about missing agent/shape.",
	)

	var shape_node := CollisionShape2D.new()
	shape_node.shape = CircleShape2D.new()
	sensor.add_child(shape_node)

	expect_true(
		sensor._get_configuration_warnings().size() < initial_warnings.size(),
		"Adding a collision shape removes the shape warning.",
	)

	sensor.detect_bodies = false
	sensor.detect_areas = false
	var disabled_warnings := sensor._get_configuration_warnings()
	expect_true(
		disabled_warnings.size() >= 2,
		"Sensor warns when both detection channels are disabled.",
	)
	sensor.free()

	var animation_binding := NucleusAnimationTreeStateBinding.new()
	expect_true(
		animation_binding._get_configuration_warnings().size() >= 2,
		"Animation binding warns when runtime dependencies are not assigned.",
	)
	animation_binding.free()

	return finish()
