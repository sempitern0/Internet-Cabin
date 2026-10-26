extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_clock_rollover_and_scale()
	_test_clock_state_restore()
	_test_day_period_classifier()
	_test_daylight_profile_and_driver()
	_test_deterministic_schedule()
	return finish()


func _test_clock_rollover_and_scale() -> void:
	var clock := NucleusWorldClock.new()

	expect_equal(
		clock.set_time_hms(2, 23, 59, 30.0),
		OK,
		"Clock accepts a valid day/time.",
	)
	clock.advance_game_seconds(90.0)

	expect_equal(clock.get_day(), 3, "Clock rolls into the next day.")
	expect_equal(clock.get_hour(), 0, "Day rollover resets hour.")
	expect_equal(clock.get_minute(), 1, "Rollover preserves elapsed minutes.")
	expect_float(clock.get_second(), 0.0, "Rollover preserves elapsed seconds.")

	clock.set_time_hms(0, 12, 0, 0.0)
	expect_float(
		clock.get_normalized_day_time(),
		0.5,
		"Noon maps to normalized day time 0.5.",
	)

	clock.set_time_scale(120.0)
	clock.advance(0.5)
	expect_equal(clock.get_minute(), 1, "Time scale converts real to game seconds.")

	expect_equal(
		clock.set_time_hms(-1, 12, 0),
		ERR_INVALID_PARAMETER,
		"Clock rejects negative logical days.",
	)
	expect_equal(
		clock.set_time_hms(0, 24, 0),
		ERR_INVALID_PARAMETER,
		"Clock rejects invalid hours.",
	)
	clock.free()


func _test_clock_state_restore() -> void:
	var clock := NucleusWorldClock.new()
	clock.set_time_hms(7, 18, 45, 12.5)
	clock.set_time_scale(30.0)
	clock.set_running(false)

	var state := clock.capture_state()
	clock.set_time_hms(0, 0, 0)
	clock.set_time_scale(1.0)
	clock.set_running(true)

	expect_equal(
		clock.restore_state(state),
		OK,
		"Clock restores captured state.",
	)
	expect_equal(clock.get_day(), 7, "Restore recovers logical day.")
	expect_equal(clock.get_hour(), 18, "Restore recovers hour.")
	expect_equal(clock.get_minute(), 45, "Restore recovers minute.")
	expect_float(clock.get_second(), 12.5, "Restore recovers fractional seconds.")
	expect_float(
		clock.game_seconds_per_real_second,
		30.0,
		"Restore recovers clock rate.",
	)
	expect_false(clock.running, "Restore recovers running state.")

	expect_equal(
		clock.restore_state({"day": 0, "seconds_of_day": 90000.0}),
		ERR_INVALID_DATA,
		"Restore rejects out-of-range seconds_of_day.",
	)
	clock.free()


func _test_day_period_classifier() -> void:
	var clock := NucleusWorldClock.new()
	var classifier := NucleusDayPeriodClassifier.new()
	classifier.clock = clock

	clock.set_time_hms(0, 4, 59, 0.0)
	expect_equal(classifier.refresh(), OK, "Classifier accepts valid boundaries.")
	expect_equal(
		classifier.get_current_period(),
		NucleusDayPeriodClassifier.DayPeriod.NIGHT,
		"Before dawn is night.",
	)

	clock.set_time_hms(0, 5, 0, 0.0)
	classifier.refresh()
	expect_equal(
		classifier.get_current_period(),
		NucleusDayPeriodClassifier.DayPeriod.DAWN,
		"Dawn begins at the configured boundary.",
	)

	clock.set_time_hms(0, 7, 0, 0.0)
	classifier.refresh()
	expect_equal(
		classifier.get_current_period(),
		NucleusDayPeriodClassifier.DayPeriod.DAY,
		"Day begins at the configured boundary.",
	)

	clock.set_time_hms(0, 18, 0, 0.0)
	classifier.refresh()
	expect_equal(
		classifier.get_current_period(),
		NucleusDayPeriodClassifier.DayPeriod.DUSK,
		"Dusk begins at the configured boundary.",
	)

	clock.set_time_hms(0, 21, 0, 0.0)
	classifier.refresh()
	expect_equal(
		classifier.get_period_id(),
		&"night",
		"Night wraps through midnight.",
	)

	classifier.day_start_hour = 4.0
	expect_equal(
		classifier.refresh(),
		ERR_INVALID_PARAMETER,
		"Classifier rejects unordered period starts.",
	)

	classifier.free()
	clock.free()


func _test_daylight_profile_and_driver() -> void:
	var clock := NucleusWorldClock.new()
	var profile := NucleusDaylightProfile.new()

	clock.set_time_hms(0, 12, 0, 0.0)
	var noon_sun := profile.sample_sun_energy(
		clock.get_normalized_day_time()
	)
	var noon_background := profile.sample_background_energy(
		clock.get_normalized_day_time()
	)

	clock.set_time_hms(0, 0, 0, 0.0)
	var midnight_sun := profile.sample_sun_energy(
		clock.get_normalized_day_time()
	)
	var midnight_background := profile.sample_background_energy(
		clock.get_normalized_day_time()
	)

	expect_true(noon_sun > midnight_sun, "Sun is brighter at noon by default.")
	expect_true(
		noon_background > midnight_background,
		"Environment fallback is brighter by day.",
	)

	var sun := DirectionalLight3D.new()
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	var driver := NucleusDaylightDriver3D.new()
	driver.clock = clock
	driver.profile = profile
	driver.sun = sun
	driver.world_environment = world_environment

	clock.set_time_hms(0, 12, 0, 0.0)
	expect_equal(driver.apply_now(), OK, "Daylight driver applies configured targets.")
	expect_float(
		sun.light_energy,
		profile.sun_energy_max,
		"Driver applies sampled noon sun energy.",
	)
	expect_float(
		world_environment.environment.background_energy_multiplier,
		profile.day_background_energy,
		"Driver applies sampled background energy.",
	)

	var missing_driver := NucleusDaylightDriver3D.new()
	expect_true(
		not missing_driver._get_configuration_warnings().is_empty(),
		"Daylight driver warns when required wiring is missing.",
	)

	missing_driver.free()
	driver.free()
	sun.free()
	world_environment.free()
	clock.free()


func _test_deterministic_schedule() -> void:
	var schedule := NucleusDeterministicSchedule.new()
	schedule.seed = 4242
	schedule.segment_duration_seconds = 21600.0
	schedule.transition_duration_seconds = 1800.0

	expect_equal(
		schedule.get_segment_index(0.0),
		0,
		"Schedule starts in segment zero.",
	)
	expect_equal(
		schedule.get_previous_segment_index(0.0),
		-1,
		"Schedule exposes the deterministic segment before the epoch.",
	)
	expect_equal(
		schedule.get_segment_index(21600.0),
		1,
		"Schedule advances at the exact segment boundary.",
	)
	expect_float(
		schedule.get_transition_alpha(21600.0),
		0.0,
		"Segment boundary starts a transition from previous to current state.",
	)
	expect_float(
		schedule.get_transition_alpha(23400.0),
		1.0,
		"Transition reaches the current segment state at configured duration.",
	)

	var first_seed := schedule.get_segment_seed(4, 2)
	expect_equal(
		first_seed,
		schedule.get_segment_seed(4, 2),
		"Segment seeds must be deterministic for the same stream.",
	)
	expect_true(
		first_seed != schedule.get_segment_seed(5, 2),
		"Different segments should derive different deterministic seeds.",
	)

	var rng_a := schedule.create_rng(8, 1)
	var rng_b := schedule.create_rng(8, 1)
	expect_equal(
		rng_a.randi(),
		rng_b.randi(),
		"Schedule-created RNG streams should replay deterministically.",
	)

	schedule.transition_duration_seconds = 30000.0
	expect_true(
		not schedule.get_validation_errors().is_empty(),
		"Schedule validation should reject transitions longer than a segment.",
	)
