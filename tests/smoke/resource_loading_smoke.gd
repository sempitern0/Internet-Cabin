extends Node

const FIXTURE_A := "res://tests/fixtures/loading/load_fixture_a.tres"
const FIXTURE_B := "res://tests/fixtures/loading/load_fixture_b.tres"
const TIMEOUT_SECONDS := 5.0

var _queue: NucleusResourceLoadQueue
var _started_usec: int = 0
var _finished: bool = false


func _ready() -> void:
	_queue = NucleusResourceLoadQueue.new()
	_queue.name = "ResourceLoadQueue"
	_queue.max_concurrent_requests = 2
	add_child(_queue)

	_queue.batch_completed.connect(_on_batch_completed)
	_queue.batch_failed.connect(_on_batch_failed)

	var plan := NucleusLoadPlan.new()
	plan.display_name = "Threaded loading smoke"
	plan.entries = [
		_entry(FIXTURE_A, NucleusLoadEntry.Priority.HIGH),
		_entry(FIXTURE_B, NucleusLoadEntry.Priority.NORMAL),
	]

	_started_usec = Time.get_ticks_usec()
	var error := _queue.start(plan)

	if error != OK:
		_fail("Could not start loading smoke batch: %s" % error_string(error))


func _process(_delta: float) -> void:
	if _finished:
		return

	var elapsed := float(Time.get_ticks_usec() - _started_usec) / 1000000.0

	if elapsed > TIMEOUT_SECONDS:
		_fail("Timed out waiting for threaded ResourceLoader requests.")


func _on_batch_completed(_plan: NucleusLoadPlan) -> void:
	if _queue.get_processed_count() != 2:
		_fail("Expected both loading fixtures to settle.")
		return

	if not is_equal_approx(_queue.get_progress(), 1.0):
		_fail("Completed loading batch did not reach progress 1.0.")
		return

	if _queue.get_retained(FIXTURE_A) == null:
		_fail("First loading fixture was not retained.")
		return

	if _queue.get_retained(FIXTURE_B) == null:
		_fail("Second loading fixture was not retained.")
		return

	_finished = true
	print("Nucleus resource-loading smoke: PASS.")
	get_tree().quit(0)


func _on_batch_failed(
	_plan: NucleusLoadPlan,
	failures: Array[Dictionary],
) -> void:
	_fail("Threaded loading batch failed: %s" % str(failures))


func _entry(path: String, priority: int) -> NucleusLoadEntry:
	var entry := NucleusLoadEntry.new()
	entry.path = path
	entry.priority = priority
	entry.retain = true
	return entry


func _fail(message: String) -> void:
	if _finished:
		return

	_finished = true
	push_error("Nucleus resource-loading smoke: " + message)
	get_tree().quit(1)
