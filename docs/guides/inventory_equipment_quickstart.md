# Inventory and Equipment Quickstart

## 1. Create item definitions

Create a `NucleusItemDefinition` Resource.

Example ammunition:

```text
item_id         = ammo_9mm
display_name    = 9mm Ammunition
max_stack_size  = 60
unit_weight     = 0.012
tags            = [ammo]
```

Do not put runtime amount inside the Resource.

## 2. Create a catalog

Create one `NucleusItemCatalog` Resource and add the definitions used by this
game/module scope.

Assign the catalog to Inventory and Equipment nodes that need ID restoration.

The catalog is data, not an Autoload.

## 3. Add an Inventory

Example player composition:

```text
Player
├── Inventory : NucleusInventory
├── Attributes : NucleusAttributeSet
└── Equipment : NucleusEquipment
```

Configure Inventory:

```text
catalog
max_slots = 30
max_weight = 50.0
```

Zero disables a limit.

## 4. Add/remove items

```gdscript
var ammo := inventory.get_definition(&"ammo_9mm")

var accepted: int = inventory.add_item(
	ammo,
	24,
)

var removed: int = inventory.remove_item(
	&"ammo_9mm",
	5,
)
```

Always use the returned amount when partial capacity matters.

## 5. Unique/stateful items

For a weapon definition:

```text
max_stack_size = 1
```

Add runtime state:

```gdscript
inventory.add_item(
	sword_definition,
	1,
	{
		"durability": 0.83,
		"quality_seed": 1427,
	},
)
```

Retrieve exact runtime instances:

```gdscript
for stack: NucleusItemStack in inventory.get_stacks():
	print(stack.stack_id)
```

## 6. Equipment definition

Create `NucleusEquipmentItemDefinition`:

```text
item_id      = iron_sword
tags         = [weapon, sword]
valid_slots  = [main_hand]
```

Add `NucleusAttributeModifier` resources such as:

```text
attribute_id = damage
operation    = ADD
value        = 5
```

Equipment does not invent another stat system.

## 7. Equipment slot

Create `NucleusEquipmentSlotDefinition`:

```text
slot_id        = main_hand
accepted_tags  = [weapon]
blocked_tags   = []
```

Assign the slot Resource to `NucleusEquipment.slots`.

Assign the same catalog.

Optionally assign:

```text
Inventory
AttributeSet
```

## 8. Equip one inventory stack

```gdscript
var stack: NucleusItemStack = inventory.get_stacks()[0]

var error := equipment.equip_inventory_stack(
	&"main_hand",
	stack.stack_id,
)
```

The stack stays in Inventory.

The Equipment node references its runtime identity and owns the corresponding
Attribute modifier source.

If the Inventory removes that stack entirely, it is automatically unequipped.

## 9. GameplayAction ammo/key requirements

Add under a `NucleusGameplayAction`:

```text
FireAction
├── InventoryItemRequirement
└── InventoryItemCost
```

Configure both with:

```text
inventory
item_id = ammo_9mm
amount = 1
```

The requirement participates in action availability.

The cost participates in transactional pay/refund.

Use this generic adapter only for fungible items. Exact-instance consumption
should use a project-specific ActionCost.

## 10. Save integration

Register explicitly:

```gdscript
save_session.register_participant(
	&"player_inventory",
	inventory.capture_state,
	inventory.restore_state,
)

save_session.register_participant(
	&"player_equipment",
	equipment.capture_state,
	equipment.restore_state,
)
```

When restoring manually, Inventory should be restored before Equipment so stack
IDs already exist.

## 11. Multiplayer rule

Do not let clients mutate authoritative Inventory directly.

Recommended model:

```text
client intent
→ server validates
→ server changes Inventory/Equipment
→ game replication sends authoritative result
```

Nucleus networking intentionally does not impose an inventory RPC protocol.

## 12. UI rule

Inventory UI is not part of this module.

Bind presentation to:

```text
inventory.changed
item_added
item_removed
stack_added
stack_removed

equipment.changed
equipped
unequipped
```

This allows a grid, list, radial selector, hotbar, or diegetic inventory to use
the same runtime storage.
