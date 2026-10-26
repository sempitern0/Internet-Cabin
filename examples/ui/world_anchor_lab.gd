extends Node3D
## Self-contained visual fixture for projected nameplates and collision budgets.

const ACTOR_COUNT: int = 8

var _actors: Array[Node3D] = []
var _camera: Camera3D
var _layout: NucleusUIWorldAnchorLayout
var _counter: Label
var _clock: float = 0.0


func _ready() -> void:
	_build_world()
	_build_hud()


func _process(delta: float) -> void:
	_clock += delta
	for index: int in range(_actors.size()):
		var actor: Node3D = _actors[index]
		var phase: float = _clock * 0.35 + float(index) * 0.55
		actor.position = Vector3(
			sin(phase) * 1.6,
			1.0 + cos(phase * 1.3) * 0.22,
			-3.5 - float(index % 3) * 1.3,
		)

	if _counter != null and _layout != null:
		_counter.text = "Visible nameplates: %d / %d" % [
			_layout.get_visible_count(), ACTOR_COUNT
		]


func _build_world() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 2.7, 7.0)
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.0, -4.0))
	_camera.current = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	add_child(light)

	for index: int in range(ACTOR_COUNT):
		var actor := MeshInstance3D.new()
		actor.mesh = SphereMesh.new()
		actor.scale = Vector3(0.35, 0.55, 0.35)
		actor.position = Vector3(0.0, 1.0, -4.0)
		add_child(actor)
		_actors.append(actor)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var overlay := Control.new()
	canvas.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var summary := Label.new()
	summary.position = Vector2(20.0, 20.0)
	summary.text = "World-space UI anchors — collision / priority / budgets"
	summary.add_theme_font_size_override(&"font_size", 20)
	overlay.add_child(summary)

	_counter = Label.new()
	_counter.position = Vector2(20.0, 50.0)
	overlay.add_child(_counter)

	_layout = NucleusUIWorldAnchorLayout.new()
	_layout.overlay = overlay
	_layout.maximum_visible_labels = ACTOR_COUNT
	_layout.maximum_lift = 110.0
	_layout.padding = 5.0
	_layout.update_interval = 0.03
	add_child(_layout)

	for index: int in range(_actors.size()):
		var tag := PanelContainer.new()
		tag.custom_minimum_size = Vector2(112.0, 29.0)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(tag)

		var name := Label.new()
		name.text = "Entity %02d" % (index + 1)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_child(name)

		var anchor := NucleusUIWorldAnchor3D.new()
		anchor.world_target = _actors[index]
		anchor.camera = _camera
		anchor.overlay = overlay
		anchor.visual = tag
		anchor.world_offset = Vector3(0.0, 0.8, 0.0)
		anchor.update_automatically = false
		add_child(anchor)
		_layout.anchors.append(anchor)
