extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	var pool := NucleusValuePool.new()
	pool.minimum_value = 0.0
	pool.maximum_value = 100.0
	pool.overflow_limit = 25.0
	pool.initial_value = 75.0
	pool._ready()

	expect_float(pool.value, 75.0, "Initial value is clamped into the pool.")
	expect_float(
		pool.increase(50.0),
		25.0,
		"Normal increase stops at maximum_value.",
	)
	expect_float(pool.value, 100.0, "Normal increase reaches the normal maximum.")

	expect_float(
		pool.increase(30.0, true),
		25.0,
		"Overflow increase stops at the configured overflow limit.",
	)
	expect_float(pool.value, 125.0, "Overflow value is retained.")
	expect_float(pool.get_overflow(), 25.0, "Overflow amount is reported.")

	expect_float(
		pool.decrease(10.0),
		-10.0,
		"Decrease consumes overflow incrementally.",
	)
	expect_float(pool.value, 115.0, "Decrease does not discard remaining overflow.")

	pool.set_value(50.0)
	pool.set_limits(0.0, 200.0, 0.0, true)
	expect_float(
		pool.value,
		100.0,
		"preserve_ratio keeps the normal-range percentage.",
	)

	var state := pool.capture_state()
	pool.set_limits(-50.0, 50.0, 10.0)
	pool.set_value(-25.0)
	pool.restore_state(state)

	expect_float(pool.minimum_value, 0.0, "State restores minimum_value.")
	expect_float(pool.maximum_value, 200.0, "State restores maximum_value.")
	expect_float(pool.value, 100.0, "State restores current value.")

	pool.free()
	return finish()
