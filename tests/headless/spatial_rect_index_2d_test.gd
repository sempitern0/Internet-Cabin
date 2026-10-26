extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_negative_space_and_order()
	_test_updates_and_reconfiguration()
	_test_overflow_and_bounded_query()
	return finish()


func _test_negative_space_and_order() -> void:
	var index := NucleusSpatialRectIndex2D.new()
	expect_equal(index.configure_cell_size(10.0), OK, "Valid cell size accepted.")
	expect_equal(index.upsert(1, Rect2(-15, -15, 20, 20), 2), OK,
		"First negative-coordinate box stored.")
	expect_equal(index.upsert(2, Rect2(-10, -10, 15, 15), 8), OK,
		"Second overlapping box stored.")
	expect_equal(index.upsert(3, Rect2(-10, -10, 15, 15), 8), OK,
		"Equal-order box stored.")
	expect_equal(index.query_point(Vector2(-8, -8)), [3, 2, 1],
		"Highest draw order first, stable descending ID ties.")
	expect_equal(index.query_point(Vector2(100, 100)).size(), 0,
		"Distant candidates excluded.")
	expect_equal(index.query_point(Vector2(INF, 0)).size(), 0,
		"Nonfinite point is rejected.")
	expect_equal(index.query_region(Rect2(-20, -20, 5, 5)), [1],
		"Region intersection is filtered to real rectangles.")


func _test_updates_and_reconfiguration() -> void:
	var index := NucleusSpatialRectIndex2D.new()
	index.configure_cell_size(8.0)
	index.upsert(7, Rect2(0, 0, 4, 4))
	index.upsert(7, Rect2(32, 32, 4, 4))
	expect_equal(index.query_point(Vector2(1, 1)).size(), 0,
		"Moving a rectangle clears its old buckets.")
	expect_equal(index.query_point(Vector2(33, 33)), [7],
		"Updated rectangle becomes discoverable.")
	expect_equal(index.configure_cell_size(4.0), OK,
		"Reconfiguring rebuilds all existing entries.")
	expect_equal(index.query_point(Vector2(33, 33)), [7],
		"Reconfigured cell index preserves contents.")
	expect_equal(index.configure_cell_size(-1.0), ERR_INVALID_PARAMETER,
		"Nonpositive cell size is rejected.")
	expect_equal(index.upsert(8, Rect2(0, 0, -4, 4)), ERR_INVALID_PARAMETER,
		"Inverted rectangle is rejected.")
	expect_true(index.remove(7), "Existing rectangle can be removed.")
	expect_false(index.remove(7), "Removing a missing rectangle is harmless.")
	expect_equal(index.size(), 0, "Removal empties the index.")


func _test_overflow_and_bounded_query() -> void:
	var index := NucleusSpatialRectIndex2D.new()
	index.configure_cell_size(2.0)
	index.max_cells_per_item = 2
	index.max_query_cells = 2
	index.upsert(5, Rect2(-100, -100, 200, 200), 10)
	index.upsert(6, Rect2(5, 5, 1, 1), 1)
	expect_equal(index.query_point(Vector2.ZERO), [5],
		"Oversized rectangles remain queryable without bucket expansion.")
	expect_equal(index.query_region(Rect2(-200, -200, 400, 400)), [5, 6],
		"Large queries fall back to a bounded exact scan.")
	expect_equal(index.query_region(Rect2(6, 6, 0, 0)), [5, 6],
		"Region boundary intersection remains inclusive by default.")
	index.clear()
	expect_equal(index.query_region(Rect2(-200, -200, 400, 400)).size(), 0,
		"Clear also removes overflow entries.")
