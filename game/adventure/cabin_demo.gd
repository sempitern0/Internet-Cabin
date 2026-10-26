extends Control
## Game-owned interaction, while Nucleus provides screen, pages and renderer.
const MAP_PATH := "res://game/adventure/cabin_map.json"
const BASE := "res://assets/cabin/"
const FONT := "res://assets/fonts/HomeVideo_Font_0_9/TrueType (.ttf)/HomeVideo-Regular.ttf"
@onready var screen: NucleusImageScreen = $Stage/Artwork/Screen
@onready var stack: NucleusScreenShaderStack = $Stage/Artwork/Screen/ShaderStack
@onready var page_label: Label = $HUD/Overlay/Status/Title
@onready var hint: Label = $HUD/Overlay/Hint
@onready var filters: CheckButton = $HUD/Overlay/Settings/Controls/Filters
@onready var strength: HSlider = $HUD/Overlay/Settings/Controls/Strength
@onready var motion: CheckButton = $HUD/Overlay/Settings/Controls/Motion
@onready var breathing: InternetCabinBreathing = $Breathing
var session: NucleusAdventureSession
var page_data: Dictionary = {}
var vhs_enabled := true
var vhs_settings := {
	"effect_strength": 0.55,
	"color_offset_multiplier": 0.004,
	"black_offset_multiplier": 0.1,
	"color_offset": 0.005,
	"blur_amount": 0.5,
}
var _hovered: StringName
var _last_hint := ""


func _ready() -> void:
	var font := load(FONT) as Font
	if font != null:
		theme = theme.duplicate(true)
		theme.default_font = font
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing cabin map")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Malformed cabin map")
		return
	var pages: Array[NucleusAdventurePage] = []
	for entry in parsed.get("pages", []):
		var page := NucleusAdventurePage.new()
		page.id = StringName(entry["id"])
		page.image = load(BASE + str(entry["image"])) as Texture2D
		if page.image == null:
			push_error("Missing artwork: " + str(entry["image"]))
			continue
		page_data[page.id] = entry
		for spec in entry.get("hotspots", []):
			var hotspot := NucleusScreenHotspot.new()
			hotspot.id = StringName(spec["id"])
			var box: Array = spec["rect"]
			hotspot.bounds = Rect2(box[0], box[1], box[2], box[3])
			hotspot.priority = int(spec.get("priority", 0))
			hotspot.description_key = StringName(spec["label"])
			if spec.has("action"):
				var action := NucleusScreenAction.new()
				var rule: Dictionary = spec["action"]
				action.next_screen = StringName(rule.get("next_screen", ""))
				action.message_key = StringName(rule.get("message_key", ""))
				for flag in rule.get("set_flags", []):
					action.set_flags.append(StringName(flag))
				for flag in rule.get("clear_flags", []):
					action.clear_flags.append(StringName(flag))
				hotspot.action = action
			else:
				hotspot.destination = StringName(spec.get("target", ""))
			page.hotspots.append(hotspot)
		pages.append(page)
	if pages.is_empty():
		push_error("No cabin artwork loaded")
		return
	session = NucleusAdventureSession.new()
	session.name = "AdventureSession"
	session.screen = screen
	session.shader_stack = stack
	session.pages = pages
	session.initial_page = StringName(parsed.get("initial_page", "overview_closed"))
	session.participant_id = &"internet_cabin_demo"
	add_child(session)
	session.page_changed.connect(_page_changed)
	session.message_requested.connect(_message_requested)
	screen.hotspot_focus_changed.connect(_focus_changed)
	# Use this game-owned connection to resolve symbolic destinations at activation time.
	screen.hotspot_activated.connect(_clicked)
	filters.toggled.connect(_toggle_vhs)
	strength.value_changed.connect(_update_strength)
	strength.set_value_no_signal(float(vhs_settings["effect_strength"]))
	motion.toggled.connect(_toggle_breathing)
	breathing.target = screen
	_apply_shader()
	_page_changed(session.current_page)


func _process(_delta: float) -> void:
	if session == null:
		return
	var local := screen.get_local_mouse_position()
	var point := screen.normalized_point(local)
	var target := screen.hotspot_at(point)
	var id: StringName = target.id if target != null else &""
	if id == _hovered:
		return
	_hovered = id
	screen.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if target != null else Control.CURSOR_ARROW
	)
	hint.text = str(target.description_key) if target != null else _last_hint


func _resolve(destination: StringName) -> StringName:
	if destination == &"@overview":
		return &"overview_open" if session.has_flag(&"door_open") else &"overview_closed"
	if destination == &"@interior_door":
		return &"door_open" if session.has_flag(&"door_open") else &"door_closed"
	return destination


func _clicked(id: StringName, _destination: StringName) -> void:
	# Nucleus handles ordinary authored destinations and stateful actions.
	# Symbolic aliases are corrected before its callback runs on page transitions.
	if id != &"":
		_last_hint = ""


func _page_changed(id: StringName) -> void:
	if not page_data.has(id):
		return
	_hovered = &""
	for region in screen.hotspots:
		if region.action == null and str(region.destination).begins_with("@"):
			region.destination = _resolve(region.destination)
	page_label.text = str(page_data[id]["title"])
	_apply_shader()
	_last_hint = ""
	hint.text = ""


func _message_requested(key: StringName) -> void:
	match key:
		&"computer_placeholder":
			_last_hint = "El ordenador espera instrucciones del trabajo..."
		&"forest_placeholder":
			_last_hint = "Fuera, apenas se distinguen los árboles."
		&"bed_placeholder":
			_last_hint = "Parece que nadie ha dormido aquí recientemente."
		_:
			_last_hint = str(key)
	hint.text = _last_hint


func _focus_changed(id: StringName) -> void:
	for region in screen.hotspots:
		if region.id == id:
			hint.text = str(region.description_key)
			return


func _toggle_vhs(on: bool) -> void:
	vhs_enabled = on
	_apply_shader()


func _apply_shader() -> void:
	if stack == null or screen.background == null:
		return
	var effects: Array[NucleusScreenEffectPass] = []
	if vhs_enabled:
		var pass_resource := NucleusScreenEffectPass.new()
		pass_resource.id = &"vhs"
		pass_resource.material = ShaderMaterial.new()
		pass_resource.material.shader = load("res://game/shaders/vhs_subtle.gdshader")
		effects.append(pass_resource)
	var result := stack.configure(screen.background, effects)
	if result != OK:
		push_error("VHS stack failed: %d" % result)
	else:
		for parameter in vhs_settings:
			stack.set_uniform(&"vhs", StringName(parameter), vhs_settings[parameter])


func _update_strength(value: float) -> void:
	vhs_settings["effect_strength"] = value
	if stack.get_pass_material(&"vhs") != null:
		stack.set_uniform(&"vhs", &"effect_strength", value)


func _toggle_breathing(on: bool) -> void:
	breathing.enabled = on


func _unhandled_key_input(event: InputEvent) -> void:
	if session == null:
		return
	if event.is_action_pressed("ui_cancel"):
		session.change_page(_resolve(&"@overview"))
		get_viewport().set_input_as_handled()
