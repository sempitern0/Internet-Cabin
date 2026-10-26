extends Node3D
## Moves the tracked point so the streaming example visibly recycles chunks.

@export_range(0.0, 1000.0, 0.1)
var speed: float = 35.0
@export_range(10.0, 10000.0, 1.0)
var travel_distance: float = 700.0

var _start_z: float = 0.0


func _ready() -> void:
	_start_z = global_position.z


func _process(delta: float) -> void:
	global_position.z += speed * delta

	if global_position.z >= _start_z + travel_distance:
		global_position.z = _start_z
