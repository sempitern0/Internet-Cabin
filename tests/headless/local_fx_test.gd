extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_quality_profile()
	_test_spawn_budget()
	_test_volume_follow_axes()
	_test_volume_intensity_and_quality()
	_test_gpu_particles_binding()
	_test_transient_surface_batch()
	return finish()


func _test_quality_profile() -> void:
	var profile := NucleusFxQualityProfile.new()

	expect_float(
		profile.get_particle_capacity_scale(
			NucleusFxQualityProfile.Quality.LOW
		),
		0.35,
		"Low FX quality should reduce continuous particle capacity.",
	)
	expect_float(
		profile.get_event_rate_scale(
			NucleusFxQualityProfile.Quality.MEDIUM
		),
		0.72,
		"Medium FX quality should reduce sparse secondary event rate.",
	)

	profile.low_event_rate_scale = -1.0
	expect_true(
		not profile.get_validation_errors().is_empty(),
		"Negative FX quality scales should fail validation.",
	)


func _test_spawn_budget() -> void:
	var budget := NucleusFxSpawnBudget.new(4, 4.0)

	expect_equal(
		budget.advance(0.1, 5.0),
		0,
		"Fractional event budget should accumulate without premature emission.",
	)
	expect_equal(
		budget.advance(0.1, 5.0),
		1,
		"Accumulated event budget should emit when one event is available.",
	)
	expect_float(
		budget.get_pending_events(),
		0.0,
		"Consumed event budget should remove the emitted whole event.",
	)
	expect_equal(
		budget.advance(10.0, 100.0),
		4,
		"Large frame deltas should be capped by the per-frame/backlog budget.",
	)
	expect_float(
		budget.get_pending_events(),
		0.0,
		"Clamped backlog should not leave an unbounded delayed burst.",
	)
	budget.advance(0.1, 5.0)
	expect_equal(
		budget.advance(0.1, 5.0, 0.0),
		0,
		"Zero effective intensity should not emit sparse FX events.",
	)
	expect_float(
		budget.get_pending_events(),
		0.0,
		"Zero effective rate should discard stale sparse-FX backlog.",
	)


func _test_volume_follow_axes() -> void:
	var root := Node3D.new()
	var target := Node3D.new()
	var volume := NucleusLocalFxVolume3D.new()
	root.name = "LocalFxTestRoot"
	root.add_child(target)
	root.add_child(volume)

	expect_true(
		attach_test_node(root),
		"Local FX transform test requires a live SceneTree.",
	)

	target.position = Vector3(10.0, 20.0, 30.0)
	volume.global_position = Vector3(1.0, 5.0, 1.0)
	volume.follow_target = target
	volume.follow_axes = (
		NucleusLocalFxVolume3D.FOLLOW_X
		| NucleusLocalFxVolume3D.FOLLOW_Z
	)
	volume.follow_offset = Vector3(2.0, 100.0, -3.0)

	expect_true(
		volume.recenter_now(),
		"Localized FX volume should recenter when followed axes changed.",
	)
	expect_true(
		volume.global_position.is_equal_approx(
			Vector3(12.0, 5.0, 27.0)
		),
		"XZ follow should preserve the volume's authored Y coordinate.",
	)

	free_test_node(root)


func _test_volume_intensity_and_quality() -> void:
	var profile := NucleusFxQualityProfile.new()
	profile.low_particle_capacity_scale = 0.25
	profile.low_event_rate_scale = 0.5

	var volume := NucleusLocalFxVolume3D.new()
	volume.set_quality_profile(profile)
	volume.set_quality(NucleusFxQualityProfile.Quality.LOW)
	volume.set_intensity(0.75, true)

	expect_float(
		volume.get_current_intensity(),
		0.75,
		"Instant intensity changes should update effective intensity.",
	)
	expect_float(
		volume.get_particle_capacity_scale(),
		0.25,
		"Volume should expose the active particle quality multiplier.",
	)
	expect_float(
		volume.get_event_rate_scale(),
		0.5,
		"Volume should expose the active secondary-event multiplier.",
	)

	volume.set_enabled(false)
	expect_float(
		volume.get_current_intensity(),
		0.0,
		"Disabled FX volume should expose zero effective intensity.",
	)
	volume.free()


func _test_gpu_particles_binding() -> void:
	var profile := NucleusFxQualityProfile.new()
	profile.low_particle_capacity_scale = 0.25

	var volume := NucleusLocalFxVolume3D.new()
	volume.set_quality_profile(profile)
	volume.set_quality(NucleusFxQualityProfile.Quality.LOW)
	volume.set_intensity(0.5, true)

	var particles := GPUParticles3D.new()
	particles.amount = 100

	var binding := NucleusGpuParticlesFxBinding3D.new()
	binding.volume = volume
	binding.particles = particles

	expect_equal(
		binding.apply_now(),
		OK,
		"GPUParticles binding should accept explicit dependencies.",
	)
	expect_equal(
		particles.amount,
		25,
		"Binding should scale authored particle capacity by FX quality.",
	)
	expect_float(
		particles.amount_ratio,
		0.5,
		"Binding should map effective volume intensity to amount_ratio.",
	)
	expect_true(
		particles.emitting,
		"Binding should emit when effective intensity is above threshold.",
	)

	volume.set_intensity(0.0, true)
	binding.apply_now()
	expect_false(
		particles.emitting,
		"Binding should stop emission at zero effective intensity.",
	)

	binding.free()
	particles.free()
	volume.free()


func _test_transient_surface_batch() -> void:
	var batch := NucleusTransientSurfaceBatch3D.new()
	batch.capacity = 2

	expect_true(
		batch.emit_surface(
			Vector3.ZERO,
			Vector3.UP,
			Vector2.ONE,
			1.0,
		),
		"Transient surface batch should accept a valid effect.",
	)
	expect_true(
		batch.emit_surface(
			Vector3.RIGHT,
			Vector3.UP,
			Vector2.ONE,
			1.0,
		),
		"Transient surface batch should fill remaining capacity.",
	)
	expect_true(
		batch.emit_surface(
			Vector3.LEFT,
			Vector3.UP,
			Vector2.ONE,
			1.0,
		),
		"Transient surface batch should recycle when capacity is full.",
	)
	expect_equal(
		batch.get_active_count(),
		2,
		"Transient surface batch must remain bounded by capacity.",
	)

	batch.advance(1.1)
	expect_equal(
		batch.get_active_count(),
		0,
		"Expired transient effects should leave the batch.",
	)
	expect_false(
		batch.emit_surface(
			Vector3.ZERO,
			Vector3.ZERO,
			Vector2.ONE,
			1.0,
		),
		"Transient surface batch should reject a zero surface normal.",
	)

	batch.free()
