extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_validation()
	_test_seeded_weighted_determinism()
	_test_zero_weight_is_never_selected()
	_test_independent_chance_boundaries()
	_test_no_duplicates_with_multiple_rolls()
	_test_guaranteed_and_random_limit()
	_test_unique_state_persistence()
	_test_amount_range()
	_test_roller_rng_state_restore()
	return finish()


func _entry(
	entry_id: StringName,
	weight: float = 1.0,
	chance: float = 1.0,
) -> NucleusLootEntry:
	var entry := NucleusLootEntry.new()
	entry.entry_id = entry_id
	entry.weight = weight
	entry.chance = chance
	return entry


func _table(
	entries: Array,
) -> NucleusLootTable:
	var table := NucleusLootTable.new()
	table.entries.assign(entries)
	return table


func _result_ids(
	results: Array[NucleusLootResult],
) -> Array[StringName]:
	var ids: Array[StringName] = []

	for result: NucleusLootResult in results:
		ids.append(result.entry_id)

	return ids


func _test_validation() -> void:
	var first := _entry(&"ore")
	var duplicate := _entry(&"ore")
	var table := _table([first, duplicate])

	expect_true(
		not table.get_validation_errors().is_empty(),
		"Loot table should reject duplicate entry IDs.",
	)


func _test_seeded_weighted_determinism() -> void:
	var table := _table([
		_entry(&"common", 8.0),
		_entry(&"rare", 2.0),
	])
	table.rolls = 12
	table.allow_duplicate_entries = true

	var first := table.roll_seeded(7123)
	var second := table.roll_seeded(7123)

	expect_equal(
		_result_ids(first),
		_result_ids(second),
		"Equal seeds should produce equal weighted result sequences.",
	)


func _test_zero_weight_is_never_selected() -> void:
	var table := _table([
		_entry(&"disabled_weight", 0.0),
		_entry(&"valid", 1.0),
	])
	table.rolls = 5
	table.allow_duplicate_entries = true

	var results := table.roll_seeded(41)

	expect_equal(
		results.size(),
		5,
		"Positive candidate should satisfy each weighted roll.",
	)

	for result: NucleusLootResult in results:
		expect_equal(
			result.entry_id,
			&"valid",
			"Zero-weight entry must never be selected.",
		)


func _test_independent_chance_boundaries() -> void:
	var table := _table([
		_entry(&"always", 1.0, 1.0),
		_entry(&"never", 1.0, 0.0),
	])
	table.roll_mode = NucleusLootTable.RollMode.INDEPENDENT_CHANCE

	var results := table.roll_seeded(2)

	expect_equal(
		results.size(),
		1,
		"Chance 1.0 should pass and chance 0.0 should fail.",
	)
	expect_equal(
		results[0].entry_id,
		&"always",
		"Boundary chance result should select only the guaranteed chance.",
	)


func _test_no_duplicates_with_multiple_rolls() -> void:
	var table := _table([
		_entry(&"a"),
		_entry(&"b"),
	])
	table.rolls = 10
	table.allow_duplicate_entries = false

	var results := table.roll_seeded(91)

	expect_equal(
		results.size(),
		2,
		"Non-duplicate weighted rolls should exhaust unique candidates.",
	)
	expect_true(
		results[0].entry_id != results[1].entry_id,
		"Each non-duplicate entry should appear at most once per call.",
	)


func _test_guaranteed_and_random_limit() -> void:
	var guaranteed := _entry(&"quest_key")
	guaranteed.guaranteed = true
	var table := _table([
		guaranteed,
		_entry(&"currency"),
	])
	table.rolls = 10
	table.maximum_random_results = 1
	table.guaranteed_count_toward_limit = false
	table.allow_duplicate_entries = true

	var results := table.roll_seeded(17)

	expect_equal(
		results.size(),
		2,
		"Guaranteed loot should not consume random budget by default.",
	)
	expect_equal(
		results[0].entry_id,
		&"quest_key",
		"Guaranteed entries should be emitted before random results.",
	)


func _test_unique_state_persistence() -> void:
	var unique := _entry(&"legendary_key")
	unique.unique = true
	var table := _table([unique])
	var state := NucleusLootState.new()

	var first := table.roll_seeded(
		5,
		state,
	)
	var second := table.roll_seeded(
		5,
		state,
	)

	expect_equal(
		first.size(),
		1,
		"Fresh unique entry should be selectable.",
	)
	expect_true(
		second.is_empty(),
		"Consumed unique entry should not roll again for the same state.",
	)

	var restored_state := NucleusLootState.new()
	restored_state.restore_state(
		state.capture_state()
	)

	expect_true(
		restored_state.has_consumed(&"legendary_key"),
		"Unique consumption should survive capture/restore.",
	)


func _test_amount_range() -> void:
	var entry := _entry(&"coins")
	entry.minimum_amount = 3
	entry.maximum_amount = 7
	var table := _table([entry])
	table.rolls = 20
	table.allow_duplicate_entries = true

	for result: NucleusLootResult in table.roll_seeded(123):
		expect_true(
			result.amount >= 3 and result.amount <= 7,
			"Rolled amount must remain inside configured inclusive range.",
		)


func _test_roller_rng_state_restore() -> void:
	var table := _table([
		_entry(&"a", 1.0),
		_entry(&"b", 1.0),
		_entry(&"c", 1.0),
	])
	table.allow_duplicate_entries = true

	var source := NucleusLootRoller.new()
	source.table = table
	source.seed_mode = NucleusLootRoller.SeedMode.FIXED
	source.fixed_seed = 811
	source._ready()
	source.generate()
	var snapshot: Dictionary = source.capture_state()
	var expected_next := _result_ids(source.generate())

	var restored := NucleusLootRoller.new()
	restored.table = table
	restored.restore_state(snapshot)
	var restored_next := _result_ids(restored.generate())

	expect_equal(
		restored_next,
		expected_next,
		"Restored RNG state should continue the exact loot sequence.",
	)

	source.free()
	restored.free()
