extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_load_order_and_budget()
	_test_stale_load_is_evicted_after_completion()
	_test_pending_desire_changes_before_admission()
	_test_redesire_during_unload()
	_test_failed_requests_require_explicit_retry()
	_test_old_completion_cannot_finish_new_retry()
	return finish()


func _test_load_order_and_budget() -> void:
	var lifecycle := NucleusWorldStreamLifecycle.new()
	lifecycle.set_automatic_processing(false)
	lifecycle.max_load_requests_per_frame = 1
	var requested: Array[StringName] = []
	var tokens: Array[int] = []
	lifecycle.load_requested.connect(
		func(region_id: StringName, request_token: int) -> void:
			requested.append(region_id)
			tokens.append(request_token)
	)

	expect_equal(
		lifecycle.set_desired_regions([&"dock", &"coast", &"island"]),
		OK,
		"Ordered desired regions should be accepted.",
	)

	lifecycle.pump()
	expect_equal(
		requested,
		[&"dock"],
		"First pump admits only the first desired region.",
	)

	expect_equal(
		lifecycle.mark_loaded(&"dock", tokens[0]),
		OK,
		"An admitted region can acknowledge successful loading.",
	)

	lifecycle.pump()
	expect_equal(
		requested,
		[&"dock", &"coast"],
		"Second pump admits the next desired region in order.",
	)

	lifecycle.free()


func _test_stale_load_is_evicted_after_completion() -> void:
	var lifecycle := NucleusWorldStreamLifecycle.new()
	lifecycle.set_automatic_processing(false)
	var unloads: Array[StringName] = []
	var load_tokens: Array[int] = []
	lifecycle.load_requested.connect(
		func(region_id: StringName, request_token: int) -> void:
			if region_id == &"near":
				load_tokens.append(request_token)
	)
	lifecycle.unload_requested.connect(
		func(region_id: StringName, _request_token: int) -> void:
			unloads.append(region_id)
	)

	lifecycle.set_desired_regions([&"near"])
	lifecycle.pump()
	lifecycle.set_desired_regions([&"far"])

	expect_equal(
		lifecycle.mark_loaded(&"near", load_tokens[0]),
		OK,
		"In-flight work may still complete after desire changes.",
	)

	lifecycle.pump()
	expect_equal(
		unloads,
		[&"near"],
		"A stale completed load is evicted on the next admission pump.",
	)
	expect_equal(
		lifecycle.get_region_state(&"far"),
		NucleusWorldStreamLifecycle.RegionState.LOADING,
		"The replacement desired region starts loading independently.",
	)

	lifecycle.free()


func _test_pending_desire_changes_before_admission() -> void:
	var lifecycle := NucleusWorldStreamLifecycle.new()
	lifecycle.set_automatic_processing(false)
	lifecycle.max_load_requests_per_frame = 1
	var requested: Array[StringName] = []
	lifecycle.load_requested.connect(
		func(region_id: StringName, _request_token: int) -> void:
			requested.append(region_id)
	)

	lifecycle.set_desired_regions([&"a", &"b"])
	lifecycle.set_desired_regions([&"b"])
	lifecycle.pump()

	expect_equal(
		requested,
		[&"b"],
		"Regions removed before admission never produce a load request.",
	)

	lifecycle.free()


func _test_redesire_during_unload() -> void:
	var lifecycle := NucleusWorldStreamLifecycle.new()
	lifecycle.set_automatic_processing(false)
	var load_tokens: Array[int] = []
	var unload_tokens: Array[int] = []
	lifecycle.load_requested.connect(
		func(_region_id: StringName, request_token: int) -> void:
			load_tokens.append(request_token)
	)
	lifecycle.unload_requested.connect(
		func(_region_id: StringName, request_token: int) -> void:
			unload_tokens.append(request_token)
	)

	expect_equal(
		lifecycle.register_loaded_region(&"harbour"),
		OK,
		"Existing scene content can seed resident lifecycle state.",
	)

	lifecycle.set_desired_regions([])
	lifecycle.pump()
	expect_equal(
		lifecycle.get_region_state(&"harbour"),
		NucleusWorldStreamLifecycle.RegionState.UNLOADING,
		"Undesired resident content receives an unload request.",
	)

	lifecycle.set_desired_regions([&"harbour"])
	expect_equal(
		lifecycle.mark_unloaded(&"harbour", unload_tokens[0]),
		OK,
		"An already admitted unload may still complete after re-desire.",
	)

	lifecycle.pump()
	expect_equal(
		load_tokens.size(),
		1,
		"Re-desired content is loaded again after stale unload completion.",
	)

	lifecycle.free()


func _test_failed_requests_require_explicit_retry() -> void:
	var lifecycle := NucleusWorldStreamLifecycle.new()
	lifecycle.set_automatic_processing(false)
	var load_tokens: Array[int] = []
	lifecycle.load_requested.connect(
		func(_region_id: StringName, request_token: int) -> void:
			load_tokens.append(request_token)
	)

	lifecycle.set_desired_regions([&"reef"])
	lifecycle.pump()
	expect_equal(
		lifecycle.mark_request_failed(
			&"reef",
			load_tokens[0],
			NucleusWorldStreamLifecycle.Operation.LOAD,
			ERR_CANT_OPEN,
		),
		OK,
		"An admitted load failure should become explicit lifecycle state.",
	)

	lifecycle.pump()
	expect_equal(
		load_tokens.size(),
		1,
		"Failed loads do not spin into automatic retry loops.",
	)

	expect_equal(
		lifecycle.retry_region(&"reef"),
		OK,
		"Consumers can explicitly retry a failed region.",
	)
	lifecycle.pump()
	expect_equal(
		load_tokens.size(),
		2,
		"Explicit retry makes the desired region eligible again.",
	)

	lifecycle.free()


func _test_old_completion_cannot_finish_new_retry() -> void:
	var lifecycle := NucleusWorldStreamLifecycle.new()
	lifecycle.set_automatic_processing(false)
	var load_tokens: Array[int] = []
	lifecycle.load_requested.connect(
		func(_region_id: StringName, request_token: int) -> void:
			load_tokens.append(request_token)
	)

	lifecycle.set_desired_regions([&"cave"])
	lifecycle.pump()
	var first_token := load_tokens[0]

	lifecycle.mark_request_failed(
		&"cave",
		first_token,
		NucleusWorldStreamLifecycle.Operation.LOAD,
		ERR_TIMEOUT,
	)
	lifecycle.retry_region(&"cave")
	lifecycle.pump()
	var second_token := load_tokens[1]

	expect_false(
		first_token == second_token,
		"Each admitted operation receives a distinct request token.",
	)
	expect_equal(
		lifecycle.mark_loaded(&"cave", first_token),
		ERR_UNAVAILABLE,
		"An old async completion cannot acknowledge a newer retry.",
	)
	expect_equal(
		lifecycle.mark_loaded(&"cave", second_token),
		OK,
		"The current request token can complete the region.",
	)

	lifecycle.free()
