extends CanvasLayer
## Runtime-only status panel for the terrain streaming example.

@export var streamer: NucleusTerrainStreamer3D
@export var tracked_node: Node3D

@onready var _label: Label = $MarginContainer/PanelContainer/MarginContainer/Label


func _process(_delta: float) -> void:
	if streamer == null or tracked_node == null:
		return

	var indices: Array[int] = streamer.get_loaded_chunk_indices()
	_label.text = (
		"Terrain streaming demo\n"
		+ "Move: automatic +Z traversal\n"
		+ "Chunk: %d\n" % streamer.get_center_chunk_index()
		+ "Loaded: %d %s\n" % [streamer.get_loaded_chunk_count(), str(indices)]
		+ "Pending: %d\n" % streamer.get_pending_chunk_count()
		+ "World Z: %.1f" % tracked_node.global_position.z
	)
