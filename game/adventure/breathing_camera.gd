extends Node
class_name InternetCabinBreathing
## Slow, delta-time independent breathing. Transform image + hit areas as one unit.
## No steps, tweens or per-scene resets: preserving phase prevents visual jumps.
@export var target: Control
@export_range(0.0, 0.025, 0.0001) var zoom_amplitude := 0.006
@export_range(0.03, 0.5, 0.01) var breathing_hz := 0.115
@export_range(0.0, 0.04, 0.0005) var idle_zoom := 0.014
@export_range(0.1, 12.0, 0.1) var response := 4.5
@export var enabled := true

var _elapsed := 0.0
var _scale := 1.0


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_elapsed += delta
	var destination := 1.0
	if enabled:
		destination = 1.0 + idle_zoom + zoom_amplitude * sin(_elapsed * TAU * breathing_hz)
	# Smoothly interpolate towards the continuous breathing curve, also when disabled.
	var blend := 1.0 - exp(-response * maxf(delta, 0.0))
	_scale = lerpf(_scale, destination, blend)
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE * _scale
