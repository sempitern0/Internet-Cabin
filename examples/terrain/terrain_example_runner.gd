@tool
extends Node
## Small example-only driver for preview and generated terrain scenes.

enum Action {
	PREVIEW,
	GENERATE,
}

@export var action: Action = Action.GENERATE
@export var run_in_editor: bool = false
@export var run_at_runtime: bool = true
@export var generator_path: NodePath = ^"../Terrain"

var _has_run: bool = false


func _ready() -> void:
	call_deferred("_run_example")


func _run_example() -> void:
	if _has_run:
		return

	if Engine.is_editor_hint() and not run_in_editor:
		return

	if not Engine.is_editor_hint() and not run_at_runtime:
		return

	var generator := get_node_or_null(generator_path) as NucleusTerrainGenerator3D

	if generator == null:
		push_warning("Terrain example could not resolve its generator.")
		return

	_has_run = true
	var error: Error = OK

	if action == Action.PREVIEW:
		error = generator.refresh_preview()
	else:
		error = generator.generate_terrain()

	if error != OK:
		push_error(
			"Terrain example failed: %s" % error_string(error)
		)
