extends Node
class_name InternetCabinBreathing
## Motion is visual-only: the image Control and its hotspots transform together.
@export var target: Control
@export_range(0.0, 0.025, 0.001) var zoom_amplitude := 0.0035
@export_range(0.0, 1.5, 0.01) var breathing_hz := 0.19
@export var enabled := true
var _elapsed := 0.0

func _process(delta: float) -> void:
	if target == null:
		return
	_elapsed += delta
	var scale_factor := 1.0
	if enabled:
		scale_factor = 1.006 + zoom_amplitude * sin(_elapsed * TAU * breathing_hz)
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE * scale_factor
