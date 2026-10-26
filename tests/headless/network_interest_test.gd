extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_cell_bounds_and_nearest_order()
	_test_updates_and_reindex()
	_test_reconciler_budgets()
	_test_reconciler_cleanup()
	return finish()


func _test_cell_bounds_and_nearest_order() -> void:
	var grid := NucleusNetworkInterestGrid3D.new()
	expect_equal(grid.set_cell_size(10.0), OK, "Grid accepts positive cell size.")
	expect_equal(
		NucleusNetworkInterestGrid3D.cell_for_position(
			Vector3(-0.1, 0.0, -10.1), 10.0
		),
		Vector2i(-1, -2),
		"Negative coordinates must use floor, not integer truncation.",
	)
	expect_equal(
		grid.upsert_entity(&"beta", Vector3(0.0, 100.0, 0.0)),
		OK,
		"Index accepts authoritative 3D positions.",
	)
	grid.upsert_entity(&"alpha", Vector3(0.0, -100.0, 0.0))
	grid.upsert_entity(&"west", Vector3(-0.5, 0.0, 0.0))
	grid.upsert_entity(&"far", Vector3(50.0, 0.0, 0.0))

	var covered: Array[Vector2i] = grid.get_covered_cells(
		Vector3(-0.1, 0.0, 0.0),
		0.5,
	)
	expect_true(
		covered.has(Vector2i(-1, 0)) and covered.has(Vector2i(0, 0)),
		"Covered cells include both sides of a negative cell boundary.",
	)
	expect_equal(
		grid.get_entities_in_cell(Vector2i(0, 0)),
		[&"alpha", &"beta"],
		"Cell listing is deduplicated and deterministic.",
	)
	expect_equal(
		grid.query_radius(Vector3.ZERO, 1.0),
		[&"alpha", &"beta", &"west"],
		"Query sorts by XZ distance, then stable entity ID.",
	)
	expect_equal(
		grid.query_radius(Vector3.ZERO, 1.0, 2),
		[&"alpha", &"beta"],
		"A requested result cap retains the closest entities.",
	)
	expect_true(
		grid.query_radius(Vector3.ZERO, 170.0).is_empty(),
		"Oversized radius is rejected rather than scanning an unbounded area.",
	)
	expect_false(
		grid.is_supported_radius(-1.0),
		"Negative radius is not supported.",
	)
	expect_equal(
		grid.upsert_entity(&"", Vector3.ZERO),
		ERR_INVALID_PARAMETER,
		"Empty network IDs cannot enter the spatial index.",
	)
	expect_equal(
		grid.upsert_entity(&"bad", Vector3(NAN, 0.0, 0.0)),
		ERR_INVALID_PARAMETER,
		"Non-finite positions cannot enter the spatial index.",
	)
	expect_equal(
		grid.set_cell_size(0.0),
		ERR_INVALID_PARAMETER,
		"Zero-size cells are rejected.",
	)


func _test_updates_and_reindex() -> void:
	var grid := NucleusNetworkInterestGrid3D.new()
	grid.set_cell_size(10.0)
	grid.upsert_entity(&"moving", Vector3(0.0, 0.0, 0.0))
	grid.upsert_entity(&"moving", Vector3(25.0, 0.0, 0.0))
	expect_equal(grid.get_entity_count(), 1, "Position update cannot duplicate IDs.")
	expect_true(
		grid.query_radius(Vector3.ZERO, 2.0).is_empty(),
		"Old cell cannot keep an updated entity.",
	)
	expect_equal(
		grid.query_radius(Vector3(25.0, 0.0, 0.0), 1.0),
		[&"moving"],
		"Updated position must appear in the new cell.",
	)
	expect_equal(grid.set_cell_size(50.0), OK, "Cell size can be reconfigured.")
	expect_equal(
		grid.query_radius(Vector3(25.0, 0.0, 0.0), 1.0),
		[&"moving"],
		"Reconfiguration rebuilds the index without losing entities.",
	)
	expect_true(grid.remove_entity(&"moving"), "Removal succeeds once.")
	expect_false(grid.remove_entity(&"moving"), "Duplicate removal is harmless.")
	expect_equal(grid.get_entity_count(), 0, "Removed entities leave the index.")


func _test_reconciler_budgets() -> void:
	var tracker := NucleusNetworkInterestReconciler.new()
	tracker.max_enters_per_pump = 1
	tracker.max_exits_per_pump = 1
	var entered: Array[StringName] = []
	var exited: Array[StringName] = []
	tracker.entity_entered.connect(func(id: StringName) -> void: entered.append(id))
	tracker.entity_exited.connect(func(id: StringName) -> void: exited.append(id))

	var first: Array[StringName] = [&"alpha", &"beta", &"alpha", &""]
	tracker.set_desired_entities(first)
	tracker.pump()
	expect_equal(str(entered), str([&"alpha"]), "Enter budget limits one pump.")
	expect_false(tracker.is_settled(), "Pending admission is observable.")
	tracker.pump()
	expect_equal(
		tracker.get_admitted_entities(),
		[&"alpha", &"beta"],
		"Second pump reaches the normalized desired set.",
	)
	expect_true(tracker.is_settled(), "All desired entities are now admitted.")

	var replacement: Array[StringName] = [&"gamma"]
	tracker.set_desired_entities(replacement)
	tracker.pump()
	expect_equal(entered, [&"alpha", &"beta", &"gamma"], "New interests enter.")
	expect_equal(exited, [&"alpha"], "Exit budget throttles stale interests.")
	tracker.pump()
	expect_equal(exited, [&"alpha", &"beta"], "Stale interests eventually exit.")
	expect_equal(tracker.get_admitted_entities(), [&"gamma"], "Only new ID remains.")
	expect_true(tracker.is_settled(), "Replacement fully reconciles.")


func _test_reconciler_cleanup() -> void:
	var tracker := NucleusNetworkInterestReconciler.new()
	var exited: Array[StringName] = []
	tracker.entity_exited.connect(func(id: StringName) -> void: exited.append(id))

	var entities: Array[StringName] = [&"one", &"two"]
	tracker.set_desired_entities(entities)
	tracker.pump()
	tracker.forget_entity(&"one")
	expect_false(tracker.is_admitted(&"one"), "Removed entity is released immediately.")
	expect_equal(exited, [&"one"], "Removal emits one exit.")
	tracker.clear_immediately()
	expect_equal(exited, [&"one", &"two"], "Peer cleanup releases remaining grants.")
	expect_true(tracker.is_settled(), "Cleared tracker is settled.")
	expect_equal(tracker.get_pending_count(), 0, "Cleanup leaves no stale work.")
