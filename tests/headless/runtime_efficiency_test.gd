extends "res://tests/headless/test_case.gd"

var _refresh_count: int = 0
var _capture_a_calls: int = 0
var _capture_b_calls: int = 0


func run() -> Dictionary:
	_test_ui_refresh_coalescer()
	_test_save_capture_job_budget()
	_test_audio_cue_priority_contract()
	return finish()


func _test_ui_refresh_coalescer() -> void:
	_refresh_count = 0
	var coalescer := NucleusUIRefreshCoalescer.new()
	coalescer.refresh_due.connect(_on_refresh_due)

	coalescer.request_refresh()
	coalescer.request_refresh()
	coalescer.request_refresh()

	expect_true(
		coalescer.is_pending(),
		"Repeated UI refresh requests should collapse into one pending update.",
	)
	expect_true(
		coalescer.flush_now(),
		"A pending UI refresh should flush once.",
	)
	expect_equal(
		_refresh_count,
		1,
		"Coalesced UI requests should emit one refresh callback.",
	)
	expect_false(
		coalescer.flush_now(),
		"A second flush without a request should stay silent.",
	)

	coalescer.free()


func _test_save_capture_job_budget() -> void:
	_capture_a_calls = 0
	_capture_b_calls = 0
	var session := NucleusSaveSession.new()

	session.register_participant(
		&"a",
		Callable(self, "_capture_a"),
	)
	session.register_participant(
		&"b",
		Callable(self, "_capture_b"),
	)

	var job: NucleusSaveCaptureJob = session.create_capture_job()

	expect_equal(job.get_total_count(), 2, "Capture job snapshots participant count.")
	expect_equal(job.step(1), 1, "Capture job respects a one-participant budget.")
	expect_false(job.is_completed(), "One remaining participant stays deferred.")
	expect_equal(job.step(1), 1, "Second step captures the remaining participant.")
	expect_true(job.is_completed(), "Capture job completes after all participants.")

	var snapshot: Dictionary = job.take_snapshot()
	expect_equal(snapshot.get("a"), 1, "First participant payload is retained.")
	expect_equal(snapshot.get("b"), 2, "Second participant payload is retained.")
	expect_equal(_capture_a_calls, 1, "First participant captures exactly once.")
	expect_equal(_capture_b_calls, 1, "Second participant captures exactly once.")

	session.free()


func _test_audio_cue_priority_contract() -> void:
	var cue := NucleusAudioCue.new()
	expect_equal(cue.voice_priority, 0, "Audio cue priority preserves legacy default.")

	cue.voice_priority = 50
	expect_equal(cue.voice_priority, 50, "Audio cues expose authored voice priority.")


func _on_refresh_due() -> void:
	_refresh_count += 1


func _capture_a() -> int:
	_capture_a_calls += 1
	return 1


func _capture_b() -> int:
	_capture_b_calls += 1
	return 2
