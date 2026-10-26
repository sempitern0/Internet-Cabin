extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_simple_celestial_source()
	_test_celestial_driver_immediate()
	_test_celestial_driver_scheduled()
	_test_daylight_driver_celestial_path()
	return finish()


func _test_simple_celestial_source() -> void:
	var source: NucleusSimpleCelestialSource3D = (
		NucleusSimpleCelestialSource3D.new()
	)
	var state: NucleusCelestialState3D = NucleusCelestialState3D.new()

	expect_equal(
		source.sample_state(0.0, state),
		OK,
		"Simple celestial source accepts normalized midnight.",
	)
	expect_false(
		state.sun_above_horizon,
		"Sun is below the horizon at midnight.",
	)
	expect_true(
		state.moon_above_horizon,
		"Moon is above the horizon at midnight.",
	)
	expect_float(
		state.daylight_factor,
		0.0,
		"Midnight has no daylight fallback contribution.",
	)
	expect_float(
		state.night_factor,
		1.0,
		"Midnight has full night fallback contribution.",
	)

	expect_equal(
		source.sample_state(0.5, state),
		OK,
		"Simple celestial source accepts normalized noon.",
	)
	expect_true(
		state.sun_above_horizon,
		"Sun is above the horizon at noon.",
	)
	expect_float(
		state.daylight_factor,
		1.0,
		"Noon reaches full daylight fallback contribution.",
	)
	expect_float(
		state.sun_direction.length(),
		1.0,
		"Celestial directions remain normalized.",
	)


func _test_celestial_driver_immediate() -> void:
	var root: Node = Node.new()
	var clock: NucleusWorldClock = NucleusWorldClock.new()
	var celestial: NucleusCelestialDriver3D = (
		NucleusCelestialDriver3D.new()
	)
	clock.set_time_hms(0, 0, 0, 0.0)
	celestial.clock = clock
	root.add_child(clock)
	root.add_child(celestial)

	expect_true(
		attach_test_node(root),
		"Celestial driver fixture requires a live SceneTree.",
	)
	expect_true(
		celestial.has_state(),
		"Celestial driver computes initial state on ready.",
	)
	expect_false(
		celestial.get_state().sun_above_horizon,
		"Initial midnight state is propagated.",
	)

	clock.set_time_hms(0, 12, 0, 0.0)

	expect_true(
		celestial.get_state().sun_above_horizon,
		"Immediate mode refreshes state with the clock.",
	)
	expect_float(
		celestial.get_state().daylight_factor,
		1.0,
		"Immediate mode derives the noon daylight factor.",
	)

	free_test_node(root)


func _test_celestial_driver_scheduled() -> void:
	var root: Node = Node.new()
	var clock: NucleusWorldClock = NucleusWorldClock.new()
	var scheduler: NucleusUpdateScheduler = NucleusUpdateScheduler.new()
	var celestial: NucleusCelestialDriver3D = (
		NucleusCelestialDriver3D.new()
	)

	clock.set_time_hms(0, 0, 0, 0.0)
	celestial.clock = clock
	celestial.scheduler = scheduler
	celestial.update_mode = (
		NucleusCelestialDriver3D.UpdateMode.SCHEDULED
	)
	celestial.update_interval = 0.1

	root.add_child(clock)
	root.add_child(scheduler)
	root.add_child(celestial)

	expect_true(
		attach_test_node(root),
		"Scheduled celestial fixture requires a live SceneTree.",
	)

	clock.set_time_hms(0, 12, 0, 0.0)

	expect_true(
		celestial.is_dirty(),
		"Scheduled mode records clock changes without writing immediately.",
	)
	expect_false(
		celestial.get_state().sun_above_horizon,
		"Scheduled state remains at the previous sample before dispatch.",
	)

	scheduler._advance(0.1)

	expect_false(
		celestial.is_dirty(),
		"Scheduler dispatch consumes pending celestial work.",
	)
	expect_true(
		celestial.get_state().sun_above_horizon,
		"Scheduled update catches up to authoritative clock time.",
	)

	free_test_node(root)


func _test_daylight_driver_celestial_path() -> void:
	var clock: NucleusWorldClock = NucleusWorldClock.new()
	var celestial: NucleusCelestialDriver3D = (
		NucleusCelestialDriver3D.new()
	)
	var profile: NucleusDaylightProfile = NucleusDaylightProfile.new()
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var driver: NucleusDaylightDriver3D = NucleusDaylightDriver3D.new()

	world_environment.environment = Environment.new()
	clock.set_time_hms(0, 12, 0, 0.0)
	celestial.clock = clock
	expect_equal(
		celestial.refresh_now(),
		OK,
		"Celestial state can be sampled without scene-tree ownership.",
	)

	driver.celestial_driver = celestial
	driver.profile = profile
	driver.sun = sun
	driver.moon = moon
	driver.world_environment = world_environment

	expect_equal(
		driver.apply_now(),
		OK,
		"Daylight driver accepts reusable celestial state.",
	)
	expect_float(
		sun.light_energy,
		profile.sun_energy_max,
		"Celestial daylight path reaches full noon sun energy.",
	)
	expect_float(
		moon.light_energy,
		0.0,
		"Celestial daylight path suppresses moon energy at noon.",
	)
	expect_equal(
		sun.rotation_degrees,
		celestial.get_state().sun_rotation_degrees,
		"Daylight driver consumes source-owned celestial rotation.",
	)
	expect_float(
		world_environment.environment.background_energy_multiplier,
		profile.day_background_energy,
		"Environment fallback consumes celestial daylight factor.",
	)

	clock.set_time_hms(0, 0, 0, 0.0)
	celestial.refresh_now()
	driver.apply_now()

	expect_float(
		sun.light_energy,
		0.0,
		"Sun energy reaches zero below the horizon.",
	)
	expect_float(
		moon.light_energy,
		profile.moon_energy_max,
		"Moon energy reaches its fallback maximum at midnight.",
	)

	driver.free()
	world_environment.free()
	moon.free()
	sun.free()
	celestial.free()
	clock.free()
