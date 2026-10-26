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
var session: NucleusAdventureSession
var page_data: Dictionary = {}
var history: Array[StringName] = []
var _suppress_history := false
var _paused := false
var _show_guides := false
var _shader_name := "YUV sutil"
var _intensity := 0.55
var _shader_name := "YUV sutil"
var _audio_events: Dictionary = {}
var _last_page: StringName
var _arrows: Control
var _pause_panel: PanelContainer
var _hint: Label
var _shader_select: OptionButton
var _shader_strength: HSlider


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
	screen.hotspot_activated.connect(_on_interaction)
	_make_hud()
	breathing.target = screen
	_on_page_changed(session.current_page)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			set_paused(not _paused)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB and not _paused:
			_show_guides = not _show_guides
			_arrows.visible = _show_guides
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _paused or session == null:
		return
	var point := screen.normalized_point(screen.get_local_mouse_position())
	var hit := screen.hotspot_at(point)
	var x := point.x
	var cursor := Control.CURSOR_ARROW
	if hit != null or (point.y >= 0 and (x < 0.09 or x > 0.91 or point.y > 0.89)):
		cursor = Control.CURSOR_POINTING_HAND
	screen.mouse_default_cursor_shape = cursor
	_hint.text = str(hit.description_key) if hit != null and _show_guides else ""


func _resolve(target: StringName) -> StringName:
	match target:
		&"@overview":
			return &"overview_open" if session.has_flag(&"door_open") else &"overview_closed"
		&"@interior_door":
			return &"door_open" if session.has_flag(&"door_open") else &"door_closed"
		&"@previous":
			return history.back() if not history.is_empty() else &"overview_closed"
	return target


func navigate(target: StringName) -> Error:
	if _paused or session == null:
		return ERR_BUSY
	if target == &"@previous" and not history.is_empty():
		var prior := history.pop_back()
		_suppress_history = true
		var result := session.change_page(prior)
		_suppress_history = false
		return result
	return session.change_page(_resolve(target))


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
	var entry: Dictionary = page_data[session.current_page]
	if pos.y >= 0.89:
		navigate(&"@previous")
	elif pos.x <= 0.09:
		navigate(StringName(entry.get("edge_left", "@previous")))
	elif pos.x >= 0.91:
		navigate(StringName(entry.get("edge_right", "@previous")))


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
		button.custom_minimum_size = Vector2(65, 75)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		_arrows.add_child(button)
		button.pressed.connect(_navigate_side.bind(side))
		button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if side == "left"
			else Control.PRESET_CENTER_RIGHT if side == "right" else Control.PRESET_CENTER_BOTTOM)
		button.position += (Vector2(12, 0) if side == "left" else Vector2(-77, 0))
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
	for name in SHADERS:
		_shader_select.add_item(name)
	_shader_select.select(1)
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
		navigate(&"@previous")
	else:
		navigate(StringName(entry.get("edge_" + side, "@previous")))


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


func _on_shader_selected(index: int) -> void:
	_shader_name = _shader_select.get_item_text(index)
	_apply_shader()


func _on_strength(value: float) -> void:
	_intensity = value
	_apply_uniforms()


func _apply_uniforms() -> void:
	var material := stack.get_pass_material(&"vhs")
	if material == null:
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
		var bus := NucleusAudioBuses.AMBIENT if str(entry.get("type")) == "ambient" else NucleusAudioBuses.SFX
		NucleusAudio.play_one_shot(audio, bus)
