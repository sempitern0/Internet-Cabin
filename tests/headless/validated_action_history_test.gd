extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_validated_restore()
	_test_branch_and_capacity()
	_test_data_safety()
	return finish()


func _test_validated_restore() -> void:
	var history := NucleusValidatedActionHistory.new()
	expect_equal(history.record({"x": 0}, {"x": 1}, &"move"), OK, "Record first action.")
	var undo: Dictionary = history.peek_undo()
	expect_equal(undo["snapshot"]["x"], 0, "Undo previews earlier state.")
	undo["snapshot"]["x"] = 99
	var next: Dictionary = history.peek_undo()
	expect_equal(next["snapshot"]["x"], 0, "Previews own a deep copy.")
	expect_equal(
		history.confirm_undo(int(undo["ticket"])),
		ERR_UNAVAILABLE,
		"A superseded undo ticket is rejected.",
	)
	expect_true(history.can_undo(), "Failed confirmation does not move cursor.")
	expect_equal(history.confirm_undo(int(next["ticket"])), OK, "Validated undo commits.")
	expect_false(history.can_undo(), "Cursor moved only on valid confirmation.")
	var redo: Dictionary = history.peek_redo()
	expect_equal(redo["snapshot"]["x"], 1, "Redo previews later state.")
	history.cancel_preview()
	expect_equal(
		history.confirm_redo(int(redo["ticket"])),
		ERR_UNAVAILABLE,
		"Cancelled restoration cannot commit.",
	)
	redo = history.peek_redo()
	expect_equal(history.confirm_redo(int(redo["ticket"])), OK, "Redo commits once.")
	expect_equal(history.confirm_redo(int(redo["ticket"])), ERR_UNAVAILABLE,
		"Duplicate acknowledgement cannot commit twice.")


func _test_branch_and_capacity() -> void:
	var history := NucleusValidatedActionHistory.new()
	history.max_actions = 2
	history.record({"x": 0}, {"x": 1}, &"one")
	history.record({"x": 1}, {"x": 2}, &"two")
	history.record({"x": 2}, {"x": 3}, &"three")
	expect_equal(history.undo_count(), 2, "Oldest entry evicted when bounded.")
	var preview: Dictionary = history.peek_undo()
	history.confirm_undo(int(preview["ticket"]))
	expect_equal(history.redo_count(), 1, "Undo exposes redo branch.")
	history.record({"x": 2}, {"x": 4}, &"alternate")
	expect_equal(history.redo_count(), 0, "New action truncates redo branch.")
	expect_equal(history.record({"x": 4}, {"x": 4}, &"noop"),
		ERR_ALREADY_EXISTS, "Equal states do not consume history.")
	expect_equal(history.undo_count(), 2, "No-op record leaves history untouched.")
	history.clear()
	expect_equal(history.undo_count(), 0, "Clear removes history.")


func _test_data_safety() -> void:
	var history := NucleusValidatedActionHistory.new()
	var before := {"nested": [{"value": 1}], "positions": PackedVector2Array([Vector2.ONE])}
	var after := {"nested": [{"value": 2}], "positions": PackedVector2Array([Vector2.ZERO])}
	expect_equal(history.record(before, after, &"nested"), OK,
		"Nested data-only values can be stored.")
	before["nested"][0]["value"] = 99
	expect_equal(history.peek_undo()["snapshot"]["nested"][0]["value"], 1,
		"Recorded data is independent of the original.")
	var node := Node.new()
	expect_equal(history.record({"node": node}, {"value": 3}, &"unsafe"),
		ERR_INVALID_DATA, "Objects cannot enter snapshot storage.")
	node.free()
	expect_equal(history.undo_count(), 1, "Rejected data preserves prior history.")
	history.max_snapshot_bytes = 8
	expect_equal(history.record({"x": 1}, {"x": 2}, &"large"),
		ERR_INVALID_DATA, "Byte budget rejects oversized snapshots.")
	expect_equal(history.undo_count(), 1, "Rejected size preserves prior history.")
