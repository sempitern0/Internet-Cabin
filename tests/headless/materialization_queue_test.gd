extends "res://tests/headless/test_case.gd"


class CountingJob:
	extends NucleusMaterializationJob

	var required_steps: int = 1
	var executed_steps: int = 0


	func _step_job() -> Error:
		executed_steps += 1
		set_progress(executed_steps, required_steps)

		if executed_steps >= required_steps:
			return complete(executed_steps)

		return OK


func run() -> Dictionary:
	_test_step_budget_and_round_robin()
	_test_stream_binding_completion()
	_test_stream_binding_cancels_stale_work()
	return finish()


func _test_step_budget_and_round_robin() -> void:
	var queue := NucleusMaterializationQueue.new()
	queue.set_automatic_processing(false)
	queue.max_steps_per_frame = 2
	queue.frame_budget_usec = 0

	var first := CountingJob.new()
	first.required_steps = 2
	var second := CountingJob.new()
	second.required_steps = 2

	expect_true(
		queue.enqueue(first) > 0,
		"Queue should accept the first incremental job.",
	)
	expect_true(
		queue.enqueue(second) > 0,
		"Queue should accept the second incremental job.",
	)

	queue.pump()

	expect_equal(
		first.executed_steps,
		1,
		"Round-robin pumping should give the first job one bounded step.",
	)
	expect_equal(
		second.executed_steps,
		1,
		"Round-robin pumping should give the second job one bounded step.",
	)
	expect_equal(
		queue.get_last_pump_steps(),
		2,
		"Step budget should cap work admitted by one pump.",
	)

	queue.pump()

	expect_true(
		first.get_state() == NucleusMaterializationJob.State.COMPLETED,
		"First job should complete on its second step.",
	)
	expect_true(
		second.get_state() == NucleusMaterializationJob.State.COMPLETED,
		"Second job should complete on its second step.",
	)
	expect_equal(
		queue.get_pending_count(),
		0,
		"Completed jobs should leave the queue.",
	)

	queue.free()


func _test_stream_binding_completion() -> void:
	var root := Node.new()
	var lifecycle := NucleusWorldStreamLifecycle.new()
	var queue := NucleusMaterializationQueue.new()
	var binding := NucleusWorldStreamMaterializationBinding.new()
	lifecycle.set_automatic_processing(false)
	queue.set_automatic_processing(false)
	binding.lifecycle = lifecycle
	binding.queue = queue
	root.add_child(lifecycle)
	root.add_child(queue)
	root.add_child(binding)

	expect_true(
		attach_test_node(root),
		"World materialization fixture requires a live SceneTree.",
	)

	var tokens: Array[int] = []
	lifecycle.load_requested.connect(
		func(_region_id: StringName, request_token: int) -> void:
			tokens.append(request_token)
	)

	lifecycle.set_desired_regions([&"island"])
	lifecycle.pump()

	var job := CountingJob.new()
	job.required_steps = 1

	expect_equal(
		binding.submit_job(
			&"island",
			tokens[0],
			NucleusWorldStreamLifecycle.Operation.LOAD,
			job,
		),
		OK,
		"Binding should accept the current world-stream request token.",
	)

	queue.pump()

	expect_equal(
		lifecycle.get_region_state(&"island"),
		NucleusWorldStreamLifecycle.RegionState.LOADED,
		"Completed materialization should acknowledge the region as loaded.",
	)
	expect_equal(
		binding.get_tracked_job_count(),
		0,
		"Completed requests should leave the stream binding.",
	)

	free_test_node(root)


func _test_stream_binding_cancels_stale_work() -> void:
	var root := Node.new()
	var lifecycle := NucleusWorldStreamLifecycle.new()
	var queue := NucleusMaterializationQueue.new()
	var binding := NucleusWorldStreamMaterializationBinding.new()
	lifecycle.set_automatic_processing(false)
	queue.set_automatic_processing(false)
	binding.lifecycle = lifecycle
	binding.queue = queue
	binding.cancel_stale_requests = true
	root.add_child(lifecycle)
	root.add_child(queue)
	root.add_child(binding)

	expect_true(
		attach_test_node(root),
		"Stale-work fixture requires a live SceneTree.",
	)

	var tokens: Array[int] = []
	lifecycle.load_requested.connect(
		func(_region_id: StringName, request_token: int) -> void:
			tokens.append(request_token)
	)

	lifecycle.set_desired_regions([&"far_island"])
	lifecycle.pump()

	var job := CountingJob.new()
	job.required_steps = 20

	expect_equal(
		binding.submit_job(
			&"far_island",
			tokens[0],
			NucleusWorldStreamLifecycle.Operation.LOAD,
			job,
		),
		OK,
		"Long materialization should be tracked by request token.",
	)

	queue.pump()
	lifecycle.set_desired_regions([])

	expect_equal(
		job.get_state(),
		NucleusMaterializationJob.State.CANCELLED,
		"Removing desire should cancel still-pending materialization.",
	)
	expect_equal(
		lifecycle.get_region_state(&"far_island"),
		NucleusWorldStreamLifecycle.RegionState.UNLOADED,
		"Cancelled load should return lifecycle state to Unloaded.",
	)
	expect_equal(
		queue.get_pending_count(),
		0,
		"Cancelled stale work should stop consuming the queue budget.",
	)

	free_test_node(root)
