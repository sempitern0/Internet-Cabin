extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_slot_filter_and_attribute_modifiers()
	_test_inventory_stack_removal_unequips()
	_test_equipment_capture_restore()
	return finish()


func _damage_attribute() -> NucleusAttributeDefinition:
	var definition := NucleusAttributeDefinition.new()
	definition.attribute_id = &"damage"
	definition.base_value = 10.0
	return definition


func _weapon() -> NucleusEquipmentItemDefinition:
	var modifier := NucleusAttributeModifier.new()
	modifier.attribute_id = &"damage"
	modifier.operation = NucleusAttributeModifier.Operation.ADD
	modifier.value = 5.0

	var weapon := NucleusEquipmentItemDefinition.new()
	weapon.item_id = &"sword"
	weapon.tags.append(&"weapon")
	weapon.valid_slots.append(&"main_hand")
	weapon.attribute_modifiers.append(modifier)
	return weapon


func _main_hand_slot() -> NucleusEquipmentSlotDefinition:
	var slot := NucleusEquipmentSlotDefinition.new()
	slot.slot_id = &"main_hand"
	slot.accepted_tags.append(&"weapon")
	return slot


func _setup() -> Dictionary:
	var weapon := _weapon()
	var catalog := NucleusItemCatalog.new()
	catalog.items.append(weapon)

	var inventory := NucleusInventory.new()
	inventory.catalog = catalog
	inventory.add_item(
		weapon,
		1,
		{"durability": 1.0},
	)

	var attributes := NucleusAttributeSet.new()
	attributes.definitions.append(_damage_attribute())
	attributes._ready()

	var equipment := NucleusEquipment.new()
	equipment.catalog = catalog
	equipment.inventory = inventory
	equipment.attribute_set = attributes
	equipment.slots.append(_main_hand_slot())
	equipment._ready()

	return {
		"weapon": weapon,
		"catalog": catalog,
		"inventory": inventory,
		"attributes": attributes,
		"equipment": equipment,
	}


func _test_slot_filter_and_attribute_modifiers() -> void:
	var context: Dictionary = _setup()
	var inventory: NucleusInventory = context["inventory"]
	var equipment: NucleusEquipment = context["equipment"]
	var attributes: NucleusAttributeSet = context["attributes"]
	var stack: NucleusItemStack = inventory.get_stacks()[0]

	expect_equal(
		equipment.equip_inventory_stack(
			&"main_hand",
			stack.stack_id,
		),
		OK,
		"Compatible inventory stack should equip.",
	)
	expect_float(
		attributes.get_value(&"damage"),
		15.0,
		"Equipped item should own an Attribute modifier source.",
	)

	equipment.free()
	inventory.free()
	attributes.free()


func _test_inventory_stack_removal_unequips() -> void:
	var context: Dictionary = _setup()
	var inventory: NucleusInventory = context["inventory"]
	var equipment: NucleusEquipment = context["equipment"]
	var attributes: NucleusAttributeSet = context["attributes"]
	var stack: NucleusItemStack = inventory.get_stacks()[0]

	equipment.equip_inventory_stack(
		&"main_hand",
		stack.stack_id,
	)
	inventory.remove_from_stack(
		stack.stack_id,
		1,
	)

	expect_false(
		equipment.is_equipped(&"main_hand"),
		"Removing an equipped inventory stack should clear its slot.",
	)
	expect_float(
		attributes.get_value(&"damage"),
		10.0,
		"Unequip should remove only the equipment modifier source.",
	)

	equipment.free()
	inventory.free()
	attributes.free()


func _test_equipment_capture_restore() -> void:
	var context: Dictionary = _setup()
	var inventory: NucleusInventory = context["inventory"]
	var equipment: NucleusEquipment = context["equipment"]
	var stack: NucleusItemStack = inventory.get_stacks()[0]

	equipment.equip_inventory_stack(
		&"main_hand",
		stack.stack_id,
	)
	var state: Dictionary = equipment.capture_state()
	equipment.clear()

	expect_false(
		equipment.is_equipped(&"main_hand"),
		"Equipment clear should empty occupied slots.",
	)

	var missing: PackedStringArray = equipment.restore_state(state)

	expect_true(
		missing.is_empty(),
		"Known equipment definitions should restore cleanly.",
	)
	expect_equal(
		equipment.get_equipped_stack_id(&"main_hand"),
		stack.stack_id,
		"Equipment persistence should preserve inventory stack identity.",
	)

	var attributes: NucleusAttributeSet = context["attributes"]
	equipment.free()
	inventory.free()
	attributes.free()
