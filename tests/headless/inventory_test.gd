extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_catalog_validation()
	_test_stacking_and_slot_capacity()
	_test_weight_capacity()
	_test_state_separates_stacks()
	_test_capture_restore()
	_test_action_adapters()
	return finish()


func _item(
	item_id: StringName,
	stack_limit: int = 1,
	weight: float = 0.0,
) -> NucleusItemDefinition:
	var item := NucleusItemDefinition.new()
	item.item_id = item_id
	item.max_stack_size = stack_limit
	item.unit_weight = weight
	return item


func _catalog(items: Array) -> NucleusItemCatalog:
	var catalog := NucleusItemCatalog.new()
	catalog.items.assign(items)
	return catalog


func _test_catalog_validation() -> void:
	var first := _item(&"ore")
	var duplicate := _item(&"ore")
	var catalog := _catalog([first, duplicate])

	expect_true(
		not catalog.get_validation_errors().is_empty(),
		"Catalog should reject duplicate item IDs.",
	)


func _test_stacking_and_slot_capacity() -> void:
	var ammo := _item(&"ammo", 10)
	var inventory := NucleusInventory.new()
	inventory.catalog = _catalog([ammo])
	inventory.max_slots = 2

	expect_equal(
		inventory.add_item(ammo, 12),
		12,
		"Inventory should fill one stack then create another.",
	)
	expect_equal(
		inventory.get_used_slots(),
		2,
		"Twelve items at stack size ten should use two slots.",
	)
	expect_equal(
		inventory.add_item(ammo, 20),
		8,
		"Slot capacity should accept only the remaining stack space.",
	)
	expect_equal(
		inventory.get_count(&"ammo"),
		20,
		"Inventory count should reflect accepted capacity.",
	)
	inventory.free()


func _test_weight_capacity() -> void:
	var ore := _item(&"ore", 20, 2.0)
	var inventory := NucleusInventory.new()
	inventory.catalog = _catalog([ore])
	inventory.max_weight = 5.0

	expect_equal(
		inventory.add_item(ore, 5),
		2,
		"Weight limit should cap accepted item count.",
	)
	expect_float(
		inventory.get_total_weight(),
		4.0,
		"Inventory weight should use definition unit_weight.",
	)
	inventory.free()


func _test_state_separates_stacks() -> void:
	var potion := _item(&"potion", 10)
	var inventory := NucleusInventory.new()
	inventory.catalog = _catalog([potion])

	inventory.add_item(
		potion,
		1,
		{"quality": "normal"},
	)
	inventory.add_item(
		potion,
		1,
		{"quality": "rare"},
	)

	expect_equal(
		inventory.get_used_slots(),
		2,
		"Different runtime state should prevent stack merging.",
	)
	inventory.free()


func _test_capture_restore() -> void:
	var sword := _item(&"sword")
	var catalog := _catalog([sword])
	var source := NucleusInventory.new()
	source.catalog = catalog
	source.add_item(
		sword,
		1,
		{"durability": 0.7},
	)

	var source_stack: NucleusItemStack = source.get_stacks()[0]
	var snapshot: Dictionary = source.capture_state()
	var restored := NucleusInventory.new()
	restored.catalog = catalog
	var missing: PackedStringArray = restored.restore_state(snapshot)
	var restored_stack: NucleusItemStack = restored.get_stacks()[0]

	expect_true(
		missing.is_empty(),
		"Known item IDs should restore without migration misses.",
	)
	expect_equal(
		restored_stack.stack_id,
		source_stack.stack_id,
		"Persistence should preserve runtime stack identity.",
	)
	expect_true(
		restored.get_stack_by_id(source_stack.stack_id) == restored_stack,
		"Stack lookup by runtime ID should return the restored stack.",
	)
	expect_equal(
		restored_stack.state.get("durability"),
		0.7,
		"Persistence should preserve per-stack state.",
	)

	source.free()
	restored.free()


func _test_action_adapters() -> void:
	var ammo := _item(&"ammo", 50)
	var inventory := NucleusInventory.new()
	inventory.catalog = _catalog([ammo])
	inventory.add_item(ammo, 5)

	var requirement := NucleusInventoryItemRequirement.new()
	requirement.inventory = inventory
	requirement.item_id = &"ammo"
	requirement.amount = 3

	var cost := NucleusInventoryItemCost.new()
	cost.inventory = inventory
	cost.item_id = &"ammo"
	cost.amount = 3

	expect_equal(
		requirement.check({}),
		OK,
		"Inventory requirement should accept sufficient quantity.",
	)
	expect_equal(
		cost.pay({}),
		OK,
		"Inventory action cost should consume sufficient quantity.",
	)
	expect_equal(
		inventory.get_count(&"ammo"),
		2,
		"Inventory cost should remove the configured amount.",
	)

	cost.refund({})

	expect_equal(
		inventory.get_count(&"ammo"),
		5,
		"Inventory cost refund should restore fungible items.",
	)

	requirement.free()
	cost.free()
	inventory.free()
