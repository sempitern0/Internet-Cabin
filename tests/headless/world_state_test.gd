extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_store_round_trip()
	_test_store_removal()
	_test_property_adapter()
	_test_transform_3d_adapter()
	_test_region_state_round_trip()
	_test_save_session_late_binding()
	return finish()


func _test_store_round_trip() -> void:
	var store := NucleusWorldStateStore.new()

	expect_equal(
		store.write_entity(
			&"forest",
			"entity-a",
			{"open": true},
		),
		OK,
		"World state should accept a valid entity record.",
	)

	var snapshot: Dictionary = store.capture_state()
	var restored := NucleusWorldStateStore.new()

	expect_equal(
		restored.restore_state(snapshot),
		OK,
		"Captured world state should restore successfully.",
	)
	expect_true(
		restored.has_entity(
			&"forest",
			"entity-a",
		),
		"Restored store should preserve entity identity.",
	)
	expect_equal(
		restored.get_entity(
			&"forest",
			"entity-a",
		).get("state", {}).get("open"),
		true,
		"Restored store should preserve entity state.",
	)


func _test_store_removal() -> void:
	var store := NucleusWorldStateStore.new()
	store.write_entity(
		&"cave",
		"pickup-a",
		{"collected": false},
	)

	expect_equal(
		store.mark_removed(
			&"cave",
			"pickup-a",
		),
		OK,
		"Persistent removal should update an existing record.",
	)
	expect_true(
		bool(
			store.get_entity(
				&"cave",
				"pickup-a",
			).get("removed", false)
		),
		"Removed entity record should stay suppressed across scene loads.",
	)


func _test_property_adapter() -> void:
	var target := Node.new()
	target.process_mode = Node.PROCESS_MODE_DISABLED

	var adapter := NucleusPropertyStateAdapter.new()
	adapter.adapter_id = &"node"
	adapter.target = target
	adapter.properties.append(&"process_mode")

	var state: Variant = adapter.capture_state()
	target.process_mode = Node.PROCESS_MODE_INHERIT
	adapter.restore_state(state)

	expect_equal(
		target.process_mode,
		Node.PROCESS_MODE_DISABLED,
		"Property adapter should restore explicit target properties.",
	)

	adapter.free()
	target.free()


func _test_transform_3d_adapter() -> void:
	var target := Node3D.new()
	target.transform = Transform3D(
		Basis.from_euler(
			Vector3(
				0.2,
				0.4,
				-0.1,
			)
		).scaled(
			Vector3(
				1.2,
				0.8,
				1.5,
			)
		),
		Vector3(
			4.0,
			2.0,
			-7.0,
		),
	)

	var adapter := NucleusTransform3DStateAdapter.new()
	adapter.adapter_id = &"transform"
	adapter.target = target
	adapter.use_global_transform = false

	var expected: Transform3D = target.transform
	var state: Variant = adapter.capture_state()
	target.transform = Transform3D.IDENTITY
	adapter.restore_state(state)

	expect_true(
		target.transform.is_equal_approx(expected),
		"Transform3D adapter should round-trip basis and origin.",
	)

	adapter.free()
	target.free()


func _test_region_state_round_trip() -> void:
	var service := NucleusWorldStateService.new()
	var region := NucleusWorldRegion.new()
	region.region_id = &"lab"

	var target := Node.new()
	region.add_child(target)

	var entity := NucleusWorldEntity.new()
	entity.persistent_id = "stable-door"
	target.add_child(entity)

	var adapter := NucleusPropertyStateAdapter.new()
	adapter.adapter_id = &"door"
	adapter.target = target
	adapter.properties.append(&"process_mode")
	entity.add_child(adapter)

	expect_equal(
		region.activate(service),
		OK,
		"Region should activate against a WorldStateService.",
	)

	target.process_mode = Node.PROCESS_MODE_DISABLED
	region.commit_all()
	target.process_mode = Node.PROCESS_MODE_INHERIT

	expect_equal(
		region.reconcile(),
		OK,
		"Region should reconcile live entities from stored state.",
	)
	expect_equal(
		target.process_mode,
		Node.PROCESS_MODE_DISABLED,
		"Re-entered world entity should receive its stored state.",
	)

	region.free()
	service.free()


func _test_save_session_late_binding() -> void:
	var source := NucleusWorldStateService.new()
	source.get_store().write_entity(
		&"village",
		"chest-1",
		{"inventory": {"coins": 4}},
	)

	var source_session := NucleusSaveSession.new()

	expect_equal(
		source.bind_save_session(source_session),
		OK,
		"WorldStateService should register as an explicit save participant.",
	)

	var snapshot: Dictionary = source_session.capture_snapshot()
	var restored_session := NucleusSaveSession.new()
	restored_session.apply_snapshot(snapshot)

	var restored := NucleusWorldStateService.new()

	expect_equal(
		restored.bind_save_session(restored_session),
		OK,
		"Late participant registration should consume pending save payload.",
	)
	expect_true(
		restored.get_store().has_entity(
			&"village",
			"chest-1",
		),
		"World state should restore even when service binds after load.",
	)

	source.unbind_save_session()
	restored.unbind_save_session()
	source.free()
	restored.free()
	source_session.free()
	restored_session.free()
