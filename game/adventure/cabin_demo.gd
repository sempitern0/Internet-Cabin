extends Control
## Scene-owned navigation, pause UI, shader auditions and audio cues.
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
var _slots: HBoxContainer
var _inspect_panel: PanelContainer
var _inspect_image: TextureRect
var _inspected_item: StringName
var _inspect_text: Label
var session: NucleusAdventureSession
var page_data: Dictionary = {}
var history: Array[StringName] = []
var _suppress_history := false
var _paused := false
var _show_guides := false
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
var _press_page: StringName
var _press_position := Vector2(-1, -1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	breathing.process_mode = Node.PROCESS_MODE_PAUSABLE
	$HUD/Overlay/Settings.hide()
	$HUD/Overlay/Status.hide()
	$HUD/Overlay/Hint.hide()
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
	session = NucleusAdventureSession.new()
	session.name = "AdventureSession"
	session.screen = screen
	session.shader_stack = stack
	session.pages = pages
	session.initial_page = StringName(data.get("initial_page", "overview_closed"))
	add_child(session)
	session.page_changed.connect(_on_page_changed)
	session.message_requested.connect(_on_message)
	screen.background_activated.connect(_on_background)
	# One owner for physical clicks: the game routes edges and hotspots.
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_normal = _load_cursor("res://assets/cursors/Circle.png")
	_cursor_hover = _load_cursor("res://assets/cursors/MidRing.png")
	_apply_game_cursor(false)
	screen.hotspot_activated.connect(_on_interaction)
	_make_hud()
	breathing.target = screen
	_on_page_changed(session.current_page)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not _paused and session != null:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if _inspect_panel != null and _inspect_panel.visible:
				return
			if _slots != null and _slots.get_global_rect().has_point(click.position):
				return
			if _show_guides and _arrows != null:
				for guide in _arrows.get_children():
					if guide is Control and guide.get_global_rect().has_point(click.position):
						return
			if click.pressed:
				_press_page = session.current_page
				_press_position = _pointer_image_point(click.position)
			else:
				var point := _pointer_image_point(click.position)
				if _press_page == session.current_page and point.x >= 0.0:
					if point.distance_to(_press_position) <= 0.025:
						_route_click(point)
				_press_page = &""
				_press_position = Vector2(-1, -1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			set_paused(not _paused)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB and not _paused:
			_show_guides = not _show_guides
			_update_arrows()
			get_viewport().set_input_as_handled()


func _pointer_image_point(viewport_point: Vector2) -> Vector2:
	var inverted := screen.get_global_transform_with_canvas().affine_inverse()
	return screen.normalized_point(inverted * viewport_point)


func _route_click(point: Vector2) -> void:
	# Reserve only a thin strip for unconditional retreat; objects win elsewhere.
	if point.y >= 0.935:
		navigate(_fallback_back())
		return
	var collectible := _find_pickup(point)
	if collectible != &"":
		inventory.pickup(collectible)
		return
	var hit := screen.hotspot_at(point)
	if hit != null:
		if hit.action == null and hit.destination != &"":
			navigate(hit.destination)
		else:
			session.activate_hotspot(hit.id)
		return
	_navigate_edge(point)


func _process(_delta: float) -> void:
	if _inspect_panel != null and _inspect_panel.visible:
		return
	if _paused or session == null:
		return
	var point := screen.normalized_point(screen.get_local_mouse_position())
	var hit := screen.hotspot_at(point)
	var x := point.x
	var active := hit != null or _find_pickup(point) != &"" or (point.y >= 0 and point.y <= 1.0
		and (x <= 0.11 or x >= 0.89 or point.y >= 0.86))
	_apply_game_cursor(active)
	_hint.text = str(hit.description_key) if hit != null and _show_guides else ""


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
	if _paused or session == null:
		return ERR_BUSY
	if target == &"@previous" and not history.is_empty():
		var prior: StringName = history.pop_back()
		_suppress_history = true
		var result := session.change_page(prior)
		_suppress_history = false
		return result
	var destination := _resolve(target)
	if destination == session.current_page:
		return OK
	return session.change_page(destination)


func _on_page_changed(id: StringName) -> void:
	if not page_data.has(id):
		return
	if not _suppress_history and not session.current_page == &"":
		# Use previous emitted page rather than the current value after change.
		if _last_page != &"" and _last_page != id:
			history.append(_last_page)
			if history.size() > 32:
				history.pop_front()
	_last_page = id
	for hotspot in screen.hotspots:
		if hotspot.action == null and str(hotspot.destination).begins_with("@"):
			hotspot.destination = _resolve(hotspot.destination)
	_apply_shader()
	_play_event("page:" + str(id))
	_update_arrows()


func _on_background(pos: Vector2) -> void:
	if _paused or not page_data.has(session.current_page):
		return
	_navigate_edge(pos)



func _fallback_back() -> StringName:
	if session == null or not page_data.has(session.current_page):
		return &"overview_closed"
	return _resolve(StringName(page_data[session.current_page].get(
		"back_target", "overview_closed")))


func _navigate_edge(point: Vector2) -> void:
	if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
		return
	var entry: Dictionary = page_data[session.current_page]
	if point.y >= 0.86:
		navigate(_fallback_back())
	elif point.x <= 0.11:
		navigate(StringName(entry.get("edge_left", _fallback_back())))
	elif point.x >= 0.89:
		navigate(StringName(entry.get("edge_right", _fallback_back())))



func _find_pickup(point: Vector2) -> StringName:
	if inventory == null or session == null or point.x < 0.0:
		return &""
	for id in inventory.items_on_page(session.current_page):
		var data: Dictionary = inventory.definitions[id]
		var rect_values: Array = inventory.world[id]["rect"]
		var area := Rect2(rect_values[0], rect_values[1],
			rect_values[2], rect_values[3])
		if area.has_point(point):
			return id
	return &""


func _make_inventory_ui() -> void:
	_slots = HBoxContainer.new()
	_slots.name = "InventorySlots"
	_slots.position = Vector2(14, 14)
	_slots.add_theme_constant_override("separation", 6)
	overlay.add_child(_slots)
	for index in range(2):
		var slot := Button.new()
		slot.name = "Pocket_%d" % index
		slot.custom_minimum_size = Vector2(48, 52)
		slot.tooltip_text = "Bolsillo %d" % (index + 1)
		slot.text = "·"
		slot.focus_mode = Control.FOCUS_ALL
		slot.pressed.connect(_slot_pressed.bind(index))
		_slots.add_child(slot)
	_inspect_panel = PanelContainer.new()
	_inspect_panel.name = "ItemExamination"
	_inspect_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_inspect_panel.custom_minimum_size = Vector2(390, 340)
	overlay.add_child(_inspect_panel)
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
	close_button.pressed.connect(func(): _inspect_panel.hide())
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
	var stacks := inventory.storage.get_stacks()
	for index in range(2):
		var button := _slots.get_child(index) as Button
		if index >= stacks.size():
			button.icon = null
			button.text = "·"
			button.tooltip_text = "Bolsillo vacío"
			continue
		var definition: NucleusItemDefinition = stacks[index].definition
		button.text = ""
		button.icon = definition.icon
		button.tooltip_text = definition.display_name


func _slot_pressed(index: int) -> void:
	var stacks := inventory.storage.get_stacks()
	if index < stacks.size():
		inventory.inspect(stacks[index].get_item_id())


func _inspect_item(id: StringName) -> void:
	_inspected_item = id
	var data: Dictionary = inventory.definitions[id]
	_inspect_image.texture = load(str(data.get("examine", ""))) as Texture2D
	_inspect_text.text = str(data.get("name", "")) + "\n" + str(data.get("description", ""))
	_inspect_panel.show()


func _drop_inspected_item() -> void:
	if session == null or _inspected_item == &"":
		return
	if inventory.discard(_inspected_item, session.current_page):
		_inspect_panel.hide()
		_show_inventory_message("Has dejado el objeto aquí.")
		_inspected_item = &""


func _show_inventory_message(message: String) -> void:
	_hint.text = message
	_hint.show()


func _on_item_picked_up(id: StringName) -> void:
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

func _on_interaction(id: StringName, _destination: StringName) -> void:
	_play_event("interaction:" + str(id))


func _on_message(key: StringName) -> void:
	_play_event("inspect:" + str(key))
	if _show_guides:
		_hint.text = str(key)


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
		_arrows.add_child(button)
		button.pressed.connect(_navigate_side.bind(side))
		button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if side == "left"
			else Control.PRESET_BOTTOM_RIGHT if side == "right" else Control.PRESET_CENTER_BOTTOM)
		button.offset_left = 16 if side == "left" else -54 if side == "right" else -19
		button.offset_right = 54 if side == "left" else -16 if side == "right" else 19
		button.offset_top = -52
		if side == "back":
			button.rotation_degrees = 90.0
			button.pivot_offset = Vector2(19, 20)
		button.offset_bottom = -12
	_arrows.hide()
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -50
	overlay.add_child(_hint)
	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PauseMenu"
	_pause_panel.custom_minimum_size = Vector2(370, 320)
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.add_child(_pause_panel)
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
	var resume := Button.new()
	resume.text = "Continuar (Esc)"
	column.add_child(resume)
	resume.pressed.connect(func(): set_paused(false))
	_pause_panel.hide()


func _navigate_side(side: String) -> void:
	if _paused or not page_data.has(session.current_page):
		return
	var entry: Dictionary = page_data[session.current_page]
	if side == "back":
		navigate(_fallback_back())
	else:
		navigate(StringName(entry.get("edge_" + side, _fallback_back())))


func _update_arrows() -> void:
	if _arrows == null or session == null:
		return
	_arrows.visible = _show_guides and not _paused


func set_paused(value: bool) -> void:
	_paused = value
	_pause_panel.visible = value
	screen.interaction_enabled = not value
	_update_arrows()
	get_tree().paused = value
	if value:
		Input.set_custom_mouse_cursor(null)
		_cursor_active = false
	else:
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
