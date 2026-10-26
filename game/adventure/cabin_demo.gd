extends Control
## Internet Cabin's scene-owned composition. Nucleus owns hit-testing and page state.
const MAP_PATH := "res://game/adventure/cabin_map.json"
const BASE := "res://assets/cabin/"
@onready var screen: NucleusImageScreen = $Layout/Stage/Artwork/Screen
@onready var stack: NucleusScreenShaderStack = $Layout/Stage/Artwork/Screen/ShaderStack
@onready var nav: HFlowContainer = $Layout/Actions
@onready var page_label: Label = $Layout/Toolbar/Title
@onready var help_label: Label = $Layout/Footer/Help
@onready var breathing: InternetCabinBreathing = $Breathing

var session: NucleusAdventureSession
var page_data: Dictionary = {}
var view_order: Array[StringName] = []
var vhs_enabled := true

func _ready() -> void:
	var font := load("res://assets/fonts/HomeVideo_Font_0_9/TrueType (.ttf)/HomeVideo-Regular.ttf") as Font
	if font != null:
		theme = theme.duplicate(true)
		theme.default_font = font
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null:
		push_error("Cabin map not found")
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("Cabin map is not valid JSON")
		return
	var pages: Array[NucleusAdventurePage] = []
	for entry in data.get("pages", []):
		var page := NucleusAdventurePage.new()
		page.id = StringName(entry["id"])
		page.image = load(BASE + str(entry["image"])) as Texture2D
		if page.image == null:
			push_error("Missing cabin art: " + str(entry["image"]))
			continue
		page_data[page.id] = entry
		view_order.append(page.id)
		for spec in entry.get("hotspots", []):
			var region := NucleusScreenHotspot.new()
			region.id = StringName(spec["id"])
			var r: Array = spec["rect"]
			region.bounds = Rect2(r[0], r[1], r[2], r[3])
			region.description_key = StringName(spec["label"])
			region.priority = int(spec.get("priority", 0))
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
	if pages.is_empty():
		push_error("No image screens could be built")
		return
	session = NucleusAdventureSession.new()
	session.name = "AdventureSession"
	session.screen = screen
	session.shader_stack = stack
	session.pages = pages
	session.initial_page = StringName(data.get("initial_page", "overview_closed"))
	session.participant_id = &"internet_cabin_demo"
	add_child(session)
	session.page_changed.connect(_page_changed)
	session.message_requested.connect(_message_requested)
	session.state_changed.connect(_sync_navigation)
	screen.hotspot_focus_changed.connect(_focus_changed)
	$Layout/Toolbar/Filters.pressed.connect(_toggle_vhs)
	$Layout/Toolbar/Motion.toggled.connect(_toggle_breathing)
	$Layout/Footer/Previous.pressed.connect(func(): _step_page(-1))
	$Layout/Footer/Next.pressed.connect(func(): _step_page(1))
	breathing.target = screen
	_apply_shader()
	_page_changed(session.current_page)

func _resolve(target: StringName) -> StringName:
	if target == &"@overview":
		return &"overview_open" if session.has_flag(&"door_open") else &"overview_closed"
	if target == &"@interior_door":
		return &"door_open" if session.has_flag(&"door_open") else &"door_closed"
	return target

func _go(target: StringName) -> void:
	var resolved := _resolve(target)
	var err := session.change_page(resolved)
	if err != OK:
		help_label.text = "Vista no disponible (%d)" % err

func _page_changed(id: StringName) -> void:
	if not page_data.has(id):
		return
	# Replace authored symbolic destinations per page, without changing the source JSON.
	for region in screen.hotspots:
		if region.action == null and str(region.destination).begins_with("@"):
			region.destination = _resolve(region.destination)
	page_label.text = page_data[id]["title"]
	_sync_navigation()

func _sync_navigation() -> void:
	if session == null or not page_data.has(session.current_page):
		return
	for child in nav.get_children():
		child.queue_free()
	for spec in page_data[session.current_page]["hotspots"]:
		var btn := Button.new()
		btn.text = spec["label"]
		btn.tooltip_text = spec["label"]
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(140, 44)
		var spec_copy: Dictionary = spec.duplicate(true)
		btn.pressed.connect(func(): _run_spec(spec_copy))
		nav.add_child(btn)

func _run_spec(spec: Dictionary) -> void:
	var key := StringName(spec["id"])
	if spec.has("target"):
		_go(StringName(spec["target"]))
	else:
		var err := session.activate_hotspot(key)
		if err != OK:
			help_label.text = "Acción no disponible"

func _message_requested(key: StringName) -> void:
	match key:
		&"computer_placeholder":
			help_label.text = "El ordenador sigue esperando instrucciones del trabajo..."
		&"forest_placeholder":
			help_label.text = "Fuera, apenas se distinguen los árboles."
		&"bed_placeholder":
			help_label.text = "Parece que nadie ha dormido aquí recientemente."
		_:
			help_label.text = str(key)

func _focus_changed(id: StringName) -> void:
	for region in screen.hotspots:
		if region.id == id:
			help_label.text = str(region.description_key)
			return

func _step_page(direction: int) -> void:
	if session == null:
		return
	var index := view_order.find(session.current_page)
	if index >= 0:
		_go(view_order[posmod(index + direction, view_order.size())])

func _toggle_vhs() -> void:
	vhs_enabled = not vhs_enabled
	_apply_shader()

func _apply_shader() -> void:
	if stack == null or screen.background == null:
		return
	var entries: Array[NucleusScreenEffectPass] = []
	if vhs_enabled:
		var effect := NucleusScreenEffectPass.new()
		effect.id = &"vhs"
		effect.material = ShaderMaterial.new()
		effect.material.shader = load("res://game/shaders/vhs_subtle.gdshader")
		entries.append(effect)
	stack.configure(screen.background, entries)

func _toggle_breathing(active: bool) -> void:
	breathing.enabled = active

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and session != null:
		_go(&"@overview")
		get_viewport().set_input_as_handled()
