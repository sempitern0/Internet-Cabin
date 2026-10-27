extends Control
## Scene-owned navigation, pause UI, shader auditions and audio cues.
const CabinSessionScript = preload("res://game/adventure/cabin_session.gd")
const SAVE_SLOT := "internet_cabin"
const MAP_PATH := "res://game/adventure/cabin_map.json"
const AUDIO_PATH := "res://game/adventure/cabin_audio_events.json"
const BASE := "res://assets/cabin/"
const SHADERS := {
	"Sin filtro": "",
	"YUV sutil": "res://game/shaders/vhs_subtle.gdshader",
	"VHS": "res://shaders/vhs.gdshader",
	"VHS suave": "res://shaders/vhs_soft.gdshader",
	"VHS postproceso": "res://shaders/vhs_post_processing.gdshader",
	"Scanlines": "res://shaders/scanlines.gdshader",
	"Fathom": "res://shaders/fathom.gdshader",
}
@onready var screen: NucleusImageScreen = $Stage/Artwork/Screen
@onready var stack: NucleusScreenShaderStack = $Stage/Artwork/Screen/ShaderStack
@onready var overlay: Control = $HUD/Overlay
@onready var breathing: InternetCabinBreathing = $Breathing
var inventory: CabinInventory
var _world_items: Node2D
var _slots: HBoxContainer
var _inspect_panel: PanelContainer
var _inspect_image: TextureRect
var _inspected_item: StringName
var _inspect_text: Label
var session: CabinSessionScript
var page_data: Dictionary = {}
var history: Array[StringName] = []
var _suppress_history := false
var _paused := false
var _restoring := false
var _save_status: Label
var _show_guides := false
var _selected_item: StringName
var _message_until := 0
var _modal: ColorRect
var _shader_name := "Fathom"
var _intensity := 0.55
var _audio_events: Dictionary = {}
var _last_page: StringName
var _arrows: Control
var _pause_panel: PanelContainer
var _hint: Label
var _shader_select: OptionButton
var _shader_strength: HSlider
var _cursor_normal: Texture2D
var _cursor_hover: Texture2D
var _cursor_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	breathing.process_mode = Node.PROCESS_MODE_PAUSABLE
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null:
		push_error("No cabin map")
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("Invalid cabin map")
		return
	if FileAccess.file_exists(AUDIO_PATH):
		var audio_file := FileAccess.open(AUDIO_PATH, FileAccess.READ)
		var events: Variant = JSON.parse_string(audio_file.get_as_text())
		if events is Dictionary:
			_audio_events = events
	var pages: Array[NucleusAdventurePage] = []
	for entry in data.get("pages", []):
		var page := NucleusAdventurePage.new()
		page.id = StringName(entry["id"])
		page.image = load(BASE + str(entry["image"])) as Texture2D
		if page.image == null:
			push_error("Missing cabin view: " + str(entry["image"]))
			continue
		page_data[page.id] = entry
		for spec in entry.get("hotspots", []):
			var region := NucleusScreenHotspot.new()
			region.id = StringName(spec["id"])
			var r: Array = spec["rect"]
			region.bounds = Rect2(r[0], r[1], r[2], r[3])
			region.priority = int(spec.get("priority", 0))
			region.description_key = StringName(spec["label"])
			if spec.has("polygon"):
				var outline := PackedVector2Array()
				for pt in spec["polygon"]:
					outline.append(Vector2(pt[0], pt[1]))
				region.polygon = outline
			if spec.has("action"):
				var action := NucleusScreenAction.new()
				var rule: Dictionary = spec["action"]
				action.next_screen = StringName(rule.get("next_screen", ""))
				action.required_item = StringName(rule.get("required_item", ""))
				action.consume_item = bool(rule.get("consume_item", false))
				action.give_item = StringName(rule.get("give_item", ""))
				for flag in rule.get("forbidden_flags", []):
					action.forbidden_flags.append(StringName(flag))
				action.one_shot = bool(rule.get("one_shot", false))
				for flag in rule.get("required_flags", []):
					action.required_flags.append(StringName(flag))
				action.message_key = StringName(rule.get("message_key", ""))
				for flag in rule.get("set_flags", []):
					action.set_flags.append(StringName(flag))
				for flag in rule.get("clear_flags", []):
					action.clear_flags.append(StringName(flag))
				region.action = action
			else:
				region.destination = StringName(spec.get("target", ""))
			page.hotspots.append(region)
		pages.append(page)
	inventory = CabinInventory.new()
	inventory.name = "CabinInventory"
	add_child(inventory)
	inventory.picked_up.connect(_on_item_picked_up)
	inventory.pickup_failed.connect(_show_inventory_message)
	inventory.inspected.connect(_inspect_item)
	_make_inventory_ui()
	_world_items = preload("res://game/inventory/cabin_world_items.gd").new()
	_world_items.screen = screen
	_world_items.inventory = inventory
	screen.add_child(_world_items)
	screen.resized.connect(_world_items.queue_redraw)
	session = CabinSessionScript.new()
	session.name = "AdventureSession"
	session.screen = screen
	session.inventory = inventory.storage
	session.interaction_requested.connect(_on_interaction)
	session.shader_stack = stack
	session.pages = pages
	session.initial_page = StringName(data.get("initial_page", "overview_closed"))
	add_child(session)
	session.page_changed.connect(_on_page_changed)
	session.message_requested.connect(_on_message)
	session.state_changed.connect(_refresh_world)
	screen.background_activated.connect(_on_background)
	# Native GUI dispatch gives HUD and modals priority over the world.
	screen.gui_input.connect(_world_gui_input)
	inventory.world_changed.connect(_refresh_world)
	_cursor_normal = _load_cursor("res://assets/cursors/Circle.png")
	_cursor_hover = _load_cursor("res://assets/cursors/MidRing.png")
	_apply_game_cursor(false, true)
	_make_hud()
	breathing.target = screen
	_on_page_changed(session.current_page)
	screen.grab_focus()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _paused:
			set_paused(false)
		elif _inspect_panel.visible:
			_close_inspection()
		elif _selected_item != &"":
			_select_item(&"")
		else:
			set_paused(true)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_BACKSPACE and not _paused and not _inspect_panel.visible:
		_navigate_side("back")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB and not _paused and not _inspect_panel.visible:
		_show_guides = not _show_guides
		_update_arrows()
		get_viewport().set_input_as_handled()


func _world_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and not _paused:
			if _inspect_panel.visible:
				_close_inspection()
			elif _selected_item != &"":
				_select_item(&"")
			else:
				_navigate_side("back")
			get_viewport().set_input_as_handled()


func _pointer_image_point(viewport_point: Vector2) -> Vector2:
	var inverted := screen.get_global_transform_with_canvas().affine_inverse()
	return screen.normalized_point(inverted * viewport_point)


func _route_click(point: Vector2) -> void:
	# Test/tool entry point uses the same target and activation as native GUI input.
	if _paused or _inspect_panel.visible:
		return
	var hit := screen.hotspot_at(point)
	if hit != null:
		screen.activate(hit.id)


func _process(_delta: float) -> void:
	if _paused or session == null or _inspect_panel.visible:
		return
	var hovered := get_viewport().gui_get_hovered_control()
	var over_world := hovered == screen
	var point := screen.normalized_point(screen.get_local_mouse_position())
	var hit := screen.hotspot_at(point) if over_world else null
	_apply_game_cursor(hit != null)
	if Time.get_ticks_msec() < _message_until:
		return
	if hit == null and screen.has_focus() and screen.focused_hotspot != &"":
		for candidate in screen.hotspots:
			if candidate.id == screen.focused_hotspot:
				hit = candidate
				break
	var prompt := str(hit.description_key) if hit != null else ""
	if _selected_item != &"":
		var item_name := str(inventory.definitions[_selected_item]["name"])
		prompt = "Usar %s · %s" % [item_name, prompt if prompt != "" else "elige un objeto"]
		prompt += "  (Esc: cancelar)"
	_hint.text = prompt


func _resolve(target: StringName) -> StringName:
	match target:
		&"@overview":
			return &"overview_open" if session.has_flag(&"door_open") else &"overview_closed"
		&"@interior_door":
			return &"door_open" if session.has_flag(&"door_open") else &"door_closed"
		&"@previous":
			return _fallback_back()
	return target


func navigate(target: StringName) -> Error:
	if _paused or session == null or _inspect_panel.visible:
		return ERR_BUSY
	if target == &"@previous" and not history.is_empty():
		var prior := _resolve(history.back())
		_suppress_history = true
		var result := session.change_page(prior)
		if result == OK:
			history.pop_back()
		_suppress_history = false
		return result
	var destination := _resolve(target)
	if destination == session.current_page:
		return OK
	var result := session.change_page(destination)
	if result != OK:
		_show_inventory_message("No puedes ir por ahí ahora.")
	return result


func _on_page_changed(id: StringName) -> void:
	if not page_data.has(id):
		return
	if not _restoring and not _suppress_history and not session.current_page == &"":
		# Use previous emitted page rather than the current value after change.
		if _last_page != &"" and _last_page != id:
			history.append(_last_page)
			if history.size() > 32:
				history.pop_front()
	_last_page = id
	_selected_item = &""
	_refresh_world()
	_refresh_inventory()
	_apply_shader()
	if not _restoring:
		_play_event("page:" + str(id))
	_update_arrows()


func _on_background(_pos: Vector2) -> void:
	if _paused or _inspect_panel.visible or not page_data.has(session.current_page):
		return
	if _selected_item != &"":
		_show_inventory_message("Elige un objeto del escenario para usarlo.")



func _fallback_back() -> StringName:
	if session == null or not page_data.has(session.current_page):
		return &"overview_closed"
	return _resolve(StringName(page_data[session.current_page].get(
		"back_target", "overview_closed")))


func _refresh_world() -> void:
	if session == null or session.current_page == &"":
		return
	var authored: Array[NucleusScreenHotspot] = []
	for page in session.pages:
		if page.id == session.current_page:
			for index in page.hotspots.size():
				var spec: Dictionary = page_data[page.id]["hotspots"][index]
				if _is_visible(spec):
					authored.append(page.hotspots[index])
			break
	for id in inventory.items_on_page(session.current_page):
		var values: Array = inventory.world[id]["rect"]
		var region := NucleusScreenHotspot.new()
		region.id = StringName("pickup:" + str(id))
		region.bounds = Rect2(values[0], values[1], values[2], values[3])
		region.priority = 100
		region.description_key = StringName("Recoger " + str(inventory.definitions[id]["name"]))
		authored.append(region)
	for side in ["left", "right", "back"]:
		if not _can_navigate_side(side):
			continue
		var region := NucleusScreenHotspot.new()
		region.id = StringName("nav:" + side)
		region.priority = 200 if side == "back" else -100
		region.bounds = Rect2(0, 0.935, 1, 0.065) if side == "back" else (
			Rect2(0, 0, 0.07, 0.935) if side == "left" else Rect2(0.93, 0, 0.07, 0.935))
		region.description_key = &"Volver" if side == "back" else &"Girar"
		authored.append(region)
	screen.hotspots = authored
	screen.queue_redraw()
	_world_items.page_id = session.current_page
	_world_items.queue_redraw()


func _make_inventory_ui() -> void:
	_slots = HBoxContainer.new()
	_slots.name = "InventorySlots"
	_slots.position = Vector2(14, 14)
	_slots.add_theme_constant_override("separation", 6)
	overlay.add_child(_slots)
	for index in range(2):
		var slot := Button.new()
		slot.name = "Pocket_%d" % index
		slot.custom_minimum_size = Vector2(60, 60)
		slot.expand_icon = true
		slot.add_theme_constant_override("icon_max_width", 36)
		slot.tooltip_text = "Bolsillo %d" % (index + 1)
		slot.text = "·"
		slot.focus_mode = Control.FOCUS_ALL
		slot.pressed.connect(_slot_pressed.bind(index))
		_slots.add_child(slot)
	_modal = ColorRect.new()
	_modal.name = "ModalShield"
	_modal.color = Color(0, 0, 0, 0.7)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(_modal)
	_modal.hide()
	_inspect_panel = PanelContainer.new()
	_inspect_panel.name = "ItemExamination"
	_inspect_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_inspect_panel.offset_left = -195
	_inspect_panel.offset_right = 195
	_inspect_panel.offset_top = -200
	_inspect_panel.offset_bottom = 200
	_modal.add_child(_inspect_panel)
	var content := VBoxContainer.new()
	_inspect_panel.add_child(content)
	_inspect_image = TextureRect.new()
	_inspect_image.custom_minimum_size = Vector2(290, 210)
	_inspect_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inspect_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(_inspect_image)
	_inspect_text = Label.new()
	_inspect_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_inspect_text)
	var close_button := Button.new()
	close_button.text = "Cerrar"
	content.add_child(close_button)
	close_button.pressed.connect(_close_inspection)
	var use_button := Button.new()
	use_button.text = "Usar en el escenario"
	content.add_child(use_button)
	use_button.pressed.connect(func():
		_select_item(_inspected_item)
		_close_inspection())
	var drop_button := Button.new()
	drop_button.text = "Dejar aquí"
	content.add_child(drop_button)
	drop_button.pressed.connect(_drop_inspected_item)
	_inspect_panel.hide()
	inventory.storage.changed.connect(_refresh_inventory)
	_refresh_inventory()


func _refresh_inventory() -> void:
	if _slots == null or inventory.storage == null:
		return
	if _selected_item != &"" and not inventory.storage.has_item(_selected_item):
		_selected_item = &""
	var stacks := inventory.storage.get_stacks()
	for index in range(2):
		var button := _slots.get_child(index) as Button
		if index >= stacks.size():
			button.modulate = Color.WHITE
			button.disabled = true
			button.icon = null
			button.text = "·"
			button.tooltip_text = "Bolsillo vacío"
			continue
		button.disabled = false
		var definition: NucleusItemDefinition = stacks[index].definition
		button.text = ""
		button.modulate = Color(1, 0.75, 0.4) if definition.item_id == _selected_item else Color.WHITE
		button.icon = definition.icon
		button.tooltip_text = definition.display_name


func _slot_pressed(index: int) -> void:
	var stacks := inventory.storage.get_stacks()
	if index < stacks.size():
		inventory.inspect(stacks[index].get_item_id())


func _inspect_item(id: StringName) -> void:
	if _paused or not inventory.storage.has_item(id):
		return
	_inspected_item = id
	var data: Dictionary = inventory.definitions[id]
	_inspect_image.texture = load(str(data.get("examine", ""))) as Texture2D
	_inspect_text.text = str(data.get("name", "")) + "\n" + str(data.get("description", ""))
	_modal.show()
	_inspect_panel.show()
	screen.interaction_enabled = false
	_update_arrows()
	_apply_game_cursor(false, true)
	_inspect_panel.get_child(0).get_child(2).grab_focus()


func _drop_inspected_item() -> void:
	if session == null or _inspected_item == &"":
		return
	if inventory.discard(_inspected_item, session.current_page):
		_close_inspection()
		_show_inventory_message("Has dejado el objeto aquí.")
		_inspected_item = &""


func _show_inventory_message(message: String) -> void:
	if _hint == null:
		return
	_hint.text = message
	_message_until = Time.get_ticks_msec() + 4500
	_hint.show()


func _on_item_picked_up(id: StringName) -> void:
	_play_event("pickup:" + str(id))
	_show_inventory_message("Recogido: " + str(inventory.definitions[id]["name"]))


func _load_cursor(path: String) -> Texture2D:
	var original := load(path) as Texture2D
	if original == null:
		return null
	var bitmap := original.get_image()
	if bitmap == null or bitmap.is_empty():
		return original
	# Maximum 32 physical pixels. Nearest resize avoids texture filtering blur.
	var length := maxi(bitmap.get_width(), bitmap.get_height())
	if length > 24:
		var ratio := 24.0 / float(length)
		bitmap.resize(maxi(1, roundi(bitmap.get_width() * ratio)),
			maxi(1, roundi(bitmap.get_height() * ratio)),
			Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(bitmap)


func _apply_game_cursor(hovering: bool, force: bool = false) -> void:
	if _paused or (not force and hovering == _cursor_active):
		return
	_cursor_active = hovering
	var image := _cursor_hover if hovering else _cursor_normal
	if image == null:
		return
	# OS cursor textures are not subject to CanvasLayer, camera or VHS scaling.
	# Keep imported PNG pixels unfiltered; the hotspot is their geometric centre.
	var hotspot := image.get_size() * 0.5
	Input.set_custom_mouse_cursor(image, Input.CURSOR_ARROW, hotspot)
	Input.set_custom_mouse_cursor(image, Input.CURSOR_POINTING_HAND, hotspot)

func _close_inspection() -> void:
	_inspect_panel.hide()
	_modal.visible = _paused
	screen.interaction_enabled = not _paused
	screen.grab_focus()
	_update_arrows()


func _select_item(id: StringName) -> void:
	_selected_item = id if id != &"" and inventory.storage.has_item(id) else &""
	_message_until = 0
	_refresh_inventory()


func _on_interaction(id: StringName, _destination: StringName) -> void:
	if _paused or _inspect_panel.visible:
		return
	if str(id).begins_with("nav:"):
		_navigate_side(str(id).trim_prefix("nav:"))
		return
	if str(id).begins_with("pickup:"):
		if _selected_item != &"":
			_show_inventory_message("Guarda el objeto seleccionado antes de recoger otro.")
		else:
			inventory.pickup(StringName(str(id).trim_prefix("pickup:")))
		return
	var spec: Dictionary = {}
	for candidate in page_data[session.current_page].get("hotspots", []):
		if StringName(candidate["id"]) == id:
			spec = candidate
			break
	if spec.is_empty() or not _is_visible(spec):
		return
	var rule: Dictionary = spec.get("action", {})
	if bool(rule.get("one_shot", false)) and session.completed.has(
		"%s/%s" % [session.current_page, id]):
		_select_item(&"")
		_show_inventory_message(str(spec.get("completed_hint",
			"Ya has examinado esto. " + str(rule.get("message_key", "")))))
		return
	var required := StringName(rule.get("required_item", ""))
	if required != &"" and _selected_item != required:
		_show_inventory_message(str(spec.get("hint", "Parece que falta algo aquí.")))
		_play_event("blocked:" + str(id))
		return
	if _selected_item != &"" and required == &"":
		_show_inventory_message("Eso no encaja aquí. Examina el objeto para buscar una pista.")
		return
	var result := OK
	if spec.has("target"):
		result = navigate(StringName(spec["target"]))
	else:
		result = session.activate_hotspot(id)
	if result == OK:
		var reward := StringName(rule.get("give_item", ""))
		if reward != &"" and inventory.storage.has_item(reward):
			inventory.world[reward]["available"] = false
			inventory.world_changed.emit()
		_play_event("interaction:" + str(id))
		_selected_item = &""
		_refresh_inventory()
	else:
		_show_inventory_message(str(spec.get("hint", "Ahora no ocurre nada más.")))


func _on_message(key: StringName) -> void:
	_play_event("inspect:" + str(key))
	var messages := {
		"forest_placeholder": "Entre los árboles no se mueve nada. Aun así, te sientes observado.",
		"computer_placeholder": "El ordenador espera un disco de respaldo en la torre.",
	}
	_show_inventory_message(str(messages.get(str(key), str(key))))


func _make_hud() -> void:
	_arrows = Control.new()
	_arrows.name = "NavigationHints"
	_arrows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_arrows)
	for side in ["left", "right", "back"]:
		var button := TextureButton.new()
		button.name = side
		button.texture_normal = load(
			"res://shaders/assets/ah-ui-next-left.png"
			if side == "left" else "res://shaders/assets/ah-ui-next-right.png"
		)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(38, 40)
		button.size = Vector2(38, 40)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.tooltip_text = "Volver (Retroceso / clic derecho)" if side == "back" else "Girar"
		button.focus_mode = Control.FOCUS_ALL
		_arrows.add_child(button)
		button.pressed.connect(_navigate_side.bind(side))
		button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if side == "left"
			else Control.PRESET_BOTTOM_RIGHT if side == "right" else Control.PRESET_CENTER_BOTTOM)
		button.offset_left = 16 if side == "left" else -54 if side == "right" else -19
		button.offset_right = 54 if side == "left" else -16 if side == "right" else 19
		button.offset_top = -52
		if side == "back":
			button.rotation_degrees = -90.0
			button.pivot_offset = Vector2(19, 20)
		button.offset_bottom = -12
	_arrows.show()
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 80
	_hint.offset_right = -80
	_hint.offset_top = -105
	_hint.offset_bottom = -60
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	overlay.add_child(_hint)
	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PauseMenu"
	_pause_panel.custom_minimum_size = Vector2(370, 320)
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_modal.add_child(_pause_panel)
	_pause_panel.offset_left = -185
	_pause_panel.offset_right = 185
	_pause_panel.offset_top = -160
	_pause_panel.offset_bottom = 160
	var column := VBoxContainer.new()
	_pause_panel.add_child(column)
	var title := Label.new()
	title.text = "PAUSA · INTERNET CABIN"
	column.add_child(title)
	_shader_select = OptionButton.new()
	for shader_label in SHADERS:
		_shader_select.add_item(shader_label)
	_shader_select.select(SHADERS.keys().find(_shader_name))
	column.add_child(_shader_select)
	_shader_select.item_selected.connect(_on_shader_selected)
	_shader_strength = HSlider.new()
	_shader_strength.min_value = 0
	_shader_strength.max_value = 1
	_shader_strength.step = 0.05
	_shader_strength.value = _intensity
	column.add_child(_shader_strength)
	_shader_strength.value_changed.connect(_on_strength)
	var breathing_toggle := CheckButton.new()
	breathing_toggle.text = "Respiración vertical"
	breathing_toggle.button_pressed = breathing.enabled
	column.add_child(breathing_toggle)
	breathing_toggle.toggled.connect(func(active: bool): breathing.enabled = active)
	var save_button := Button.new()
	save_button.text = "Guardar partida"
	column.add_child(save_button)
	save_button.pressed.connect(func(): save_progress())
	var load_button := Button.new()
	load_button.text = "Cargar partida"
	column.add_child(load_button)
	load_button.pressed.connect(func(): load_progress())
	_save_status = Label.new()
	_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_save_status)
	var resume := Button.new()
	resume.text = "Continuar (Esc)"
	column.add_child(resume)
	resume.pressed.connect(func(): set_paused(false))
	_pause_panel.hide()
	overlay.move_child(_modal, -1)


func _is_visible(spec: Dictionary) -> bool:
	for flag in spec.get("visible_when", []):
		if not session.has_flag(StringName(flag)):
			return false
	for flag in spec.get("hidden_when", []):
		if session.has_flag(StringName(flag)):
			return false
	return true


func _side_target(side: String) -> StringName:
	var entry: Dictionary = page_data[session.current_page]
	return _fallback_back() if side == "back" else _resolve(
		StringName(entry.get("edge_" + side, _fallback_back())))


func _can_navigate_side(side: String) -> bool:
	if session == null or not page_data.has(session.current_page):
		return false
	var target := _side_target(side)
	return page_data.has(target) and target != session.current_page


func _navigate_side(side: String) -> void:
	if _paused or _inspect_panel.visible or not page_data.has(session.current_page):
		return
	if _can_navigate_side(side):
		navigate(_side_target(side))


func _update_arrows() -> void:
	if _arrows == null or session == null:
		return
	_arrows.visible = not _paused and not _inspect_panel.visible
	_hint.visible = _arrows.visible
	for button in _arrows.get_children():
		button.visible = (button.name == "back" or _show_guides) and _can_navigate_side(
			str(button.name))


func set_paused(value: bool) -> void:
	_paused = value
	_pause_panel.visible = value
	_modal.visible = value or _inspect_panel.visible
	screen.interaction_enabled = not value and not _inspect_panel.visible
	_update_arrows()
	get_tree().paused = value
	if value:
		_shader_select.grab_focus()
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
		_cursor_active = false
	else:
		screen.grab_focus()
		_apply_game_cursor(false, true)


func _on_shader_selected(index: int) -> void:
	_shader_name = _shader_select.get_item_text(index)
	_apply_shader()


func _on_strength(value: float) -> void:
	_intensity = value
	_apply_uniforms()


func _apply_uniforms() -> void:
	var shader_material := stack.get_pass_material(&"vhs")
	if shader_material == null:
		return
	if _shader_name == "YUV sutil":
		stack.set_uniform(&"vhs", &"effect_strength", _intensity)
	elif _shader_name == "VHS postproceso":
		stack.set_uniform(&"vhs", &"filter_intensity", _intensity)
	elif _shader_name == "Fathom":
		stack.set_uniform(&"vhs", &"vignette_strength", _intensity)
	elif _shader_name == "VHS":
		stack.set_uniform(&"vhs", &"colorOffsetIntensity", 0.1 + _intensity)
	elif _shader_name == "VHS suave":
		stack.set_uniform(&"vhs", &"color_displacement", _intensity * 2.0)
	elif _shader_name == "Scanlines":
		stack.set_uniform(&"vhs", &"scanline_alpha", 1.0 - _intensity * 0.3)


func _apply_shader() -> void:
	if screen.background == null:
		return
	var effects: Array[NucleusScreenEffectPass] = []
	var path: String = SHADERS.get(_shader_name, "")
	if path != "":
		var effect := NucleusScreenEffectPass.new()
		effect.id = &"vhs"
		effect.material = ShaderMaterial.new()
		effect.material.shader = load(path) as Shader
		if effect.material.shader == null:
			push_error("Failed to load shader: " + path)
			return
		if _shader_name == "VHS postproceso":
			effect.material.set_shader_parameter(
				"noise_texture", load("res://shaders/assets/rgba-noise-medium.png"))
		effects.append(effect)
	var err := stack.configure(screen.background, effects)
	if err != OK:
		push_error("Filter configuration error: %d" % err)
	else:
		_apply_uniforms()


func _play_event(event_id: String) -> void:
	if not _audio_events.has(event_id):
		return
	var entry: Variant = _audio_events[event_id]
	if not entry is Dictionary:
		return
	var path := str(entry.get("stream", ""))
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		return
	var audio := load(path) as AudioStream
	if audio == null:
		return
	if str(entry.get("type", "sfx")) == "music":
		NucleusAudio.music.play(audio, float(entry.get("fade", 0.6)))
	else:
		var bus := NucleusAudioBuses.SFX
		if str(entry.get("type")) == "ambient":
			bus = NucleusAudioBuses.AMBIENT
		NucleusAudio.play_one_shot(audio, bus)


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	if _paused:
		get_tree().paused = false


func capture_progress() -> Dictionary:
	return {"version": 1, "adventure": session.capture_state(),
		"items": inventory.capture_state()}


func restore_progress(snapshot: Dictionary) -> Error:
	if snapshot.get("version") != 1:
		return ERR_FILE_UNRECOGNIZED
	var adventure: Variant = snapshot.get("adventure")
	var items: Variant = snapshot.get("items")
	if not adventure is Dictionary or not items is Dictionary:
		return ERR_INVALID_DATA
	if not inventory.validate_state(items):
		return ERR_INVALID_DATA
	for location in items["world"].values():
		if not page_data.has(StringName(location["page"])):
			return ERR_DOES_NOT_EXIST
	# Validate inventory first, then let Nucleus accept the adventure snapshot.
	# A rejected adventure must not clear the current selection through inventory signals.
	_restoring = true
	var result := session.restore_state(adventure)
	if result == OK:
		inventory.restore_state(items)
		history.clear()
		_selected_item = &""
		_inspected_item = &""
		_close_inspection()
		if _paused:
			_shader_select.grab_focus()
		_refresh_inventory()
	_restoring = false
	return result


func save_progress(slot_id: String = SAVE_SLOT) -> Error:
	var result := NucleusSave.save_manual(slot_id, capture_progress())
	_save_status.text = "Partida guardada." if result.succeeded() else "No se pudo guardar."
	return OK if result.succeeded() else ERR_CANT_CREATE


func load_progress(slot_id: String = SAVE_SLOT) -> Error:
	var result := NucleusSave.load_manual(slot_id)
	if not result.succeeded():
		_save_status.text = "No se pudo cargar una partida válida."
		return ERR_CANT_OPEN
	var restored := restore_progress(result.document.payload)
	_save_status.text = "Partida cargada." if restored == OK else "Partida incompatible."
	return restored
