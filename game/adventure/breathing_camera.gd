extends Node
class_name InternetCabinBreathing
## Gentle eye-level vertical motion; never changes a hotspot relative to its art.
## Constant overscan keeps the 4:3 edges covered while the screen translates.
@export var target: Control
@export_range(0.0, 0.025, 0.0005) var vertical_amplitude := 0.009
@export_range(0.03, 0.5, 0.005) var breathing_hz := 0.135
@export_range(1.0, 1.08, 0.001) var overscan_scale := 1.03
@export_range(0.1, 12.0, 0.1) var response := 5.0
@export var enabled := true

var _elapsed := 0.0
var _displacement := 0.0
var _scale := 1.0


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_elapsed += maxf(delta, 0.0)
	var phase := sin(_elapsed * TAU * breathing_hz)
	var requested := target.size.y * vertical_amplitude * phase if enabled else 0.0
	var requested_scale := overscan_scale if enabled else 1.0
	# Exponential smoothing is stable across different monitor frame rates.
	var weight := 1.0 - exp(-response * maxf(delta, 0.0))
	_displacement = lerpf(_displacement, requested, weight)
	_scale = lerpf(_scale, requested_scale, weight)
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE * _scale
	# Keep the camera movement orthogonal to zoom, never alter authored UVs.
	target.position = Vector2(0.0, _displacement)


func reset_motion() -> void:
	_elapsed = 0.0
	_displacement = 0.0
	_scale = 1.0
	if is_instance_valid(target):
		target.position = Vector2.ZERO
		target.scale = Vector2.ONE
