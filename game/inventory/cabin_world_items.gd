extends Node2D
## Draw after the background, before the Nucleus backbuffer filter overlays.
## This child inherits the exact image transform, including breathing motion.
var screen: NucleusImageScreen
var inventory: CabinInventory
var page_id: StringName
var _textures: Dictionary = {}


func _draw() -> void:
	if inventory == null or screen == null:
		return
	var area := screen.image_rect()
	for id in inventory.items_on_page(page_id):
		var values: Array = inventory.world[id]["rect"]
		var bounds := Rect2(values[0], values[1], values[2], values[3])
		# World art is optional; never fall back to a square inventory card.
		var path := str(inventory.definitions[id].get("world_texture", ""))
		if path.is_empty():
			continue
		if not _textures.has(path):
			_textures[path] = load(path) as Texture2D
		var icon := _textures[path] as Texture2D
		if icon == null:
			continue
		var target := Rect2(area.position + bounds.position * area.size, bounds.size * area.size)
		var factor := minf(target.size.x / icon.get_width(), target.size.y / icon.get_height())
		var drawn := icon.get_size() * factor
		draw_texture_rect(icon, Rect2(target.get_center() - drawn * 0.5, drawn), false)
