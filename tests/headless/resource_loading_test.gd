extends "res://tests/headless/test_case.gd"

const FIXTURE_A := "res://tests/fixtures/loading/load_fixture_a.tres"


func run() -> Dictionary:
	_test_entry_validation_and_label()
	_test_plan_validation_and_weight()
	_test_cached_resource_fast_path()
	_test_required_failure_marks_batch_failed()
	_test_optional_failure_does_not_fail_batch()
	return finish()


func _test_entry_validation_and_label() -> void:
	var entry := NucleusLoadEntry.new()
	expect_false(
		entry.get_validation_errors().is_empty(),
		"Load entries should reject an empty path.",
	)

	entry.path = "res://game/example.tres"
	entry.display_name = "Example"
	expect_true(
		entry.get_validation_errors().is_empty(),
		"A valid res:// entry should pass structural validation.",
	)
	expect_equal(
		entry.get_display_name(),
		"Example",
		"Authored display names should drive presentation labels.",
	)

	entry.display_name = ""
	expect_equal(
		entry.get_display_name(),
		"example.tres",
		"Entries without a label should fall back to the resource filename.",
	)


func _test_plan_validation_and_weight() -> void:
	var first := _entry("res://game/first.tres", 1.5)
	var second := _entry("res://game/second.tres", 2.5)
	var plan := NucleusLoadPlan.new()
	plan.entries = [first, second]

	expect_true(
		plan.get_validation_errors().is_empty(),
		"Unique valid load entries should form a valid plan.",
	)
	expect_equal(plan.get_item_count(), 2, "Plan should expose its authored item count.")
	expect_float(plan.get_total_weight(), 4.0, "Plan should sum developer-authored weights.")

	plan.entries.append(_entry("res://game/first.tres"))
	expect_false(
		plan.get_validation_errors().is_empty(),
		"Duplicate paths should be rejected so progress remains deterministic.",
	)


func _test_cached_resource_fast_path() -> void:
	var cached := ResourceLoader.load(FIXTURE_A)
	expect_true(cached != null, "Loading fixture should enter Godot's resource cache.")

	var queue := NucleusResourceLoadQueue.new()
	expect_true(
		attach_test_node(queue),
		"Resource queue tests require an active SceneTree.",
	)

	var plan := NucleusLoadPlan.new()
	plan.entries = [_entry(FIXTURE_A)]

	expect_equal(queue.start(plan), OK, "Cached load plan should be admitted.")
	expect_equal(
		queue.state,
		NucleusResourceLoadQueue.State.COMPLETED,
		"Cached resources should complete without waiting for a polling frame.",
	)
	expect_float(queue.get_progress(), 1.0, "Completed cached batch reaches full progress.")
	expect_equal(queue.get_processed_count(), 1, "Cached resource counts as processed.")
	expect_true(queue.has_retained(FIXTURE_A), "Retained cached resource stays referenced.")
	expect_true(
		queue.get_retained(FIXTURE_A) == cached,
		"Queue should reuse Godot's cached resource instead of loading a duplicate.",
	)

	free_test_node(queue)


func _test_required_failure_marks_batch_failed() -> void:
	var queue := NucleusResourceLoadQueue.new()
	expect_true(
		attach_test_node(queue),
		"Required-failure queue test requires an active SceneTree.",
	)

	var missing := _entry("res://tests/fixtures/loading/does_not_exist.tres")
	var plan := NucleusLoadPlan.new()
	plan.entries = [missing]

	expect_equal(queue.start(plan), OK, "Structurally valid missing paths start normally.")
	expect_equal(
		queue.state,
		NucleusResourceLoadQueue.State.FAILED,
		"A required missing resource should fail the completed batch.",
	)
	expect_equal(queue.get_failures().size(), 1, "Required failure should be recorded.")
	expect_float(queue.get_progress(), 1.0, "Terminal failures still settle plan progress.")

	free_test_node(queue)


func _test_optional_failure_does_not_fail_batch() -> void:
	var cached := ResourceLoader.load(FIXTURE_A)
	expect_true(cached != null, "Optional-failure fixture should be cached.")
	var queue := NucleusResourceLoadQueue.new()
	expect_true(
		attach_test_node(queue),
		"Optional-failure queue test requires an active SceneTree.",
	)

	var missing := _entry("res://tests/fixtures/loading/optional_missing.tres")
	missing.required = false
	var plan := NucleusLoadPlan.new()
	plan.entries = [missing, _entry(FIXTURE_A)]

	expect_equal(queue.start(plan), OK, "Mixed optional/cached plan should start.")
	expect_equal(
		queue.state,
		NucleusResourceLoadQueue.State.COMPLETED,
		"Optional resource failures should not fail the whole batch.",
	)
	expect_equal(queue.get_failures().size(), 1, "Optional failure remains observable.")
	expect_equal(queue.get_processed_count(), 2, "Both terminal items should be counted.")

	free_test_node(queue)


func _entry(path: String, weight: float = 1.0) -> NucleusLoadEntry:
	var entry := NucleusLoadEntry.new()
	entry.path = path
	entry.weight = weight
	return entry
