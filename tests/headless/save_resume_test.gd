extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_microsecond_document_roundtrip()
	_test_latest_candidate_selection()
	_test_kind_normalization()
	return finish()


func _test_microsecond_document_roundtrip() -> void:
	var document := NucleusSaveDocument.new()
	document.slot_id = "slot"
	document.updated_at_unix = 100
	document.updated_at_unix_usec = 100000123
	document.created_at_unix = 90
	document.created_at_unix_usec = 90000123

	var restored := NucleusSaveDocument.from_dictionary(
		document.to_dictionary()
	)

	expect_true(restored != null, "Save document should round-trip.")
	expect_equal(
		restored.get_updated_at_usec(),
		100000123,
		"Save document should preserve microsecond update timestamps.",
	)
	expect_equal(
		restored.get_created_at_usec(),
		90000123,
		"Save document should preserve microsecond creation timestamps.",
	)

	var legacy := NucleusSaveDocument.new()
	legacy.updated_at_unix = 42
	expect_equal(
		legacy.get_updated_at_usec(),
		42000000,
		"Legacy save documents should derive microseconds from whole seconds.",
	)


func _test_latest_candidate_selection() -> void:
	var manual := _result(
		NucleusSaveTypes.Kind.MANUAL,
		200000001,
	)
	var autosave := _result(
		NucleusSaveTypes.Kind.AUTOSAVE,
		200000002,
	)
	var quick := _result(
		NucleusSaveTypes.Kind.QUICKSAVE,
		199999999,
	)
	var candidates: Array[NucleusSaveResult] = [
		manual,
		autosave,
		quick,
	]

	expect_true(
		NucleusSaveResumePolicy.choose_latest(candidates) == autosave,
		"Newest timestamp should win resume selection regardless of save kind.",
	)

	manual.document.updated_at_unix_usec = 300000000
	autosave.document.updated_at_unix_usec = 300000000

	expect_true(
		NucleusSaveResumePolicy.choose_latest(candidates) == autosave,
		"Default exact-timestamp ties should prefer autosave.",
	)

	var manual_first := PackedInt32Array([
		NucleusSaveTypes.Kind.MANUAL,
		NucleusSaveTypes.Kind.AUTOSAVE,
	])
	expect_true(
		NucleusSaveResumePolicy.choose_latest(
			candidates,
			manual_first,
		) == manual,
		"Explicit kind order should decide exact-timestamp ties.",
	)


func _test_kind_normalization() -> void:
	var normalized := NucleusSaveResumePolicy.normalize_kind_order(
		PackedInt32Array([
			NucleusSaveTypes.Kind.MANUAL,
			NucleusSaveTypes.Kind.MANUAL,
			999,
			NucleusSaveTypes.Kind.QUICKSAVE,
		])
	)

	expect_equal(normalized.size(), 2, "Resume kind order should remove duplicates.")
	expect_equal(
		normalized[0],
		NucleusSaveTypes.Kind.MANUAL,
		"Resume kind normalization should preserve caller order.",
	)
	expect_equal(
		normalized[1],
		NucleusSaveTypes.Kind.QUICKSAVE,
		"Resume kind normalization should keep valid later kinds.",
	)


func _result(
	kind: int,
	updated_at_usec: int,
) -> NucleusSaveResult:
	var document := NucleusSaveDocument.new()
	document.kind = kind
	document.updated_at_unix = int(updated_at_usec / 1000000)
	document.updated_at_unix_usec = updated_at_usec

	var result := NucleusSaveResult.new()
	result.document = document
	result.error = OK
	return result
