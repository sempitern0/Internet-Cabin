extends Node
class_name CabinInventory
## Scene-owned two-item inventory on top of the Nucleus inventory module.
signal inspected(item_id: StringName)
signal pickup_failed(reason: String)
signal picked_up(item_id: StringName)

const DATA := "res://game/inventory/cabin_items.json"
var storage: NucleusInventory
var definitions: Dictionary = {}
var world: Dictionary = {}

func _ready() -> void:
	var file := FileAccess.open(DATA, FileAccess.READ)
	if file == null:
		push_error("Missing cabin item catalog")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var catalog := NucleusItemCatalog.new()
	for spec in parsed.get("items", []):
		var id := StringName(spec.get("id", ""))
		if id == &"":
			continue
		var definition := NucleusItemDefinition.new()
		definition.item_id = id
		definition.display_name = str(spec.get("name", id))
		definition.description = str(spec.get("description", ""))
		definition.icon = load(str(spec.get("icon", ""))) as Texture2D
		definition.max_stack_size = 1
		catalog.items.append(definition)
		definitions[id] = spec
		world[id] = {
			"page": spec["start"]["page"],
			"rect": spec["start"]["rect"],
			"available": true,
		}
	storage = NucleusInventory.new()
	storage.name = "Storage"
	storage.max_slots = 2
	storage.catalog = catalog
	add_child(storage)

func pickup(id: StringName) -> bool:
	if storage == null or not definitions.has(id):
		return false
	if storage.has_item(id):
		return false
	if not world[id]["available"]:
		return false
	if not storage.can_add_item(storage.get_definition(id)):
		pickup_failed.emit("Solo puedes llevar dos objetos.")
		return false
	if storage.add_item_by_id(id) != 1:
		return false
	world[id]["available"] = false
	picked_up.emit(id)
	return true

func inspect(id: StringName) -> void:
	if storage != null and storage.has_item(id):
		inspected.emit(id)

func discard(id: StringName, page_id: StringName) -> bool:
	if storage == null or storage.remove_item(id) != 1:
		return false
	world[id] = {
		"page": String(page_id),
		"rect": [0.43, 0.77, 0.14, 0.11],
		"available": true,
	}
	return true

func items_on_page(page_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in definitions:
		if world[id]["available"] and StringName(world[id]["page"]) == page_id:
			result.append(id)
	return result

func capture_state() -> Dictionary:
	return {"inventory": storage.capture_state(), "world": world.duplicate(true)}

func restore_state(state: Dictionary) -> void:
	storage.restore_state(state.get("inventory", {}))
	var saved: Variant = state.get("world", {})
	if saved is Dictionary:
		for id in world:
			if saved.has(id):
				world[id] = saved[id].duplicate(true)
