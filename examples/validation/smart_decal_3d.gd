extends Node3D

@onready var floor_decal: NucleusSmartDecal3D = $FloorDecal
@onready var sphere_decal: NucleusSmartDecal3D = $SphereDecal
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	floor_decal.place_on_surface(
		Vector3(-1.4, 0.16, 0.0),
		Vector3.UP,
		Vector3.RIGHT,
		false,
		false,
	)

	var sphere_center := Vector3(1.4, 1.0, 0.0)
	var sphere_normal := Vector3(-0.55, 0.75, 0.35).normalized()

	sphere_decal.place_on_surface(
		sphere_center + sphere_normal,
		sphere_normal,
		Vector3.FORWARD,
		false,
		false,
	)

	camera.look_at(
		Vector3(0.0, 0.7, 0.0),
		Vector3.UP,
	)
