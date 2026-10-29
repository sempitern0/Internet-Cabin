extends Node
class_name CabinInventory
## Scene-owned two-item inventory on top of the Nucleus inventory module.
signal world_changed
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
			"available": bool(spec.get("available", true)),
		}
	storage = NucleusInventory.new()
	storage.name = "Storage"
	storage.max_slots = 2
	storage.catalog = catalog
	add_child(storage)

func is_collectible(id: StringName) -> bool:
	return definitions.has(id) and bool(definitions[id].get("collectible", true))


func can_pickup(id: StringName) -> bool:
	return (storage != null and is_collectible(id) and bool(world[id]["available"])
		and not storage.has_item(id) and storage.can_add_item(storage.get_definition(id)))


func can_inspect(id: StringName) -> bool:
	return (storage != null and definitions.has(id)
		and (storage.has_item(id) or bool(world[id]["available"])))


func pickup(id: StringName) -> bool:
	if storage == null or not is_collectible(id):
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
	world_changed.emit()
	picked_up.emit(id)
	return true

func inspect(id: StringName) -> void:
	if can_inspect(id):
		inspected.emit(id)

func discard(id: StringName, page_id: StringName) -> bool:
	if storage == null or page_id == &"" or not definitions.has(id):
		return false
	var placement := _drop_rect(page_id)
	if placement.is_empty():
		pickup_failed.emit("No queda espacio aquí. Prueba en otra vista.")
		return false
	if storage.remove_item(id) != 1:
		return false
	world[id] = {
		"page": String(page_id),
		"rect": placement,
		"available": true,
	}
	world_changed.emit()
	return true

func items_on_page(page_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in definitions:
		if world[id]["available"] and StringName(world[id]["page"]) == page_id:
			result.append(id)
	return result

func capture_state() -> Dictionary:
	return {"inventory": storage.capture_state(), "world": world.duplicate(true)}

func restore_state(state: Dictionary) -> bool:
	if not validate_state(state):
		return false
	world = state["world"].duplicate(true)
	storage.restore_state(state["inventory"])
	world_changed.emit()
	return true


func validate_state(state: Dictionary) -> bool:
	# Nucleus allows over-capacity restoration for migrations; this game does not.
	# Validate the complete snapshot before touching either writable owner.
	var bag: Variant = state.get("inventory")
	var saved: Variant = state.get("world")
	if not bag is Dictionary or not saved is Dictionary:
		return false
	var entries: Variant = bag.get("stacks")
	if not entries is Array or entries.size() > 2:
		return false
	var held := {}
	for entry in entries:
		if not entry is Dictionary or entry.get("amount") != 1:
			return false
		var id := StringName(str(entry.get("item_id", "")))
		if not is_collectible(id) or held.has(id):
			return false
		held[id] = true
	for id in definitions:
		var location: Variant = saved.get(id)
		if not location is Dictionary or not location.get("available") is bool:
			return false
		if not location.get("page") is String or str(location["page"]).is_empty():
			return false
		if held.has(id) and location["available"]:
			return false
		var values: Variant = location.get("rect")
		if not values is Array or values.size() != 4:
			return false
		for value in values:
			if not (value is float or value is int) or not is_finite(float(value)):
				return false
		var rect := Rect2(values[0], values[1], values[2], values[3])
		if not rect.has_area() or rect.position.x < 0 or rect.position.y < 0:
			return false
		if rect.end.x > 1 or rect.end.y > 0.935:
			return false
	return true


func _drop_rect(page_id: StringName) -> Array:
	# Allocate a free visible cell, independent of catalog size or ordering.
	for row in range(2):
		for column in range(6):
			var candidate := Rect2(0.08 + column * 0.14, 0.79 - row * 0.13, 0.12, 0.11)
			var occupied := false
			for item_id in items_on_page(page_id):
				var r: Array = world[item_id]["rect"]
				if candidate.intersects(Rect2(r[0], r[1], r[2], r[3])):
					occupied = true
					break
			if not occupied:
				return [candidate.position.x, candidate.position.y,
					candidate.size.x, candidate.size.y]
	return []
