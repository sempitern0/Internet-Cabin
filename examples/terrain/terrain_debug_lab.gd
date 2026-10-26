extends CanvasLayer
## Runtime controls for the terrain debug/prototype example.

@export var terrain: NucleusTerrainGenerator3D

@onready var _view: OptionButton = %DebugView
@onready var _wireframe: CheckButton = %Wireframe
@onready var _stats: Label = %Stats


func _ready() -> void:
	_view.add_item("Material", NucleusTerrainMaterialProfile.DebugView.MATERIAL)
	_view.add_item("Height bands", NucleusTerrainMaterialProfile.DebugView.HEIGHT_BANDS)
	_view.add_item("Slope", NucleusTerrainMaterialProfile.DebugView.SLOPE)
	_view.add_item("Normals", NucleusTerrainMaterialProfile.DebugView.NORMALS)
	_view.add_item(
		"Layer weights",
		NucleusTerrainMaterialProfile.DebugView.LAYER_WEIGHTS,
	)
	_view.add_item("World grid", NucleusTerrainMaterialProfile.DebugView.WORLD_GRID)
	_view.select(terrain.debug_view)
	_wireframe.button_pressed = terrain.debug_wireframe
	_view.item_selected.connect(_on_view_selected)
	_wireframe.toggled.connect(_on_wireframe_toggled)


func _process(_delta: float) -> void:
	if terrain == null:
		return

	var snapshot: Dictionary = terrain.get_debug_snapshot()
	var diagnostics := terrain.get_live_diagnostics()
	_stats.text = (
		"Prototype / Debug Terrain\n"
		+ "Patches: %s\n" % snapshot.get("patch_count", 0)
		+ "Resolution: %s\n" % snapshot.get("resolution", 0)
		+ "Triangles/patch: %s\n" % snapshot.get("triangles_per_patch", 0)
		+ "Base triangles: %s\n" % snapshot.get("estimated_base_triangles", 0)
		+ "LOD levels: %s\n" % snapshot.get("lod_levels", 0)
		+ "Layers: %s\n" % snapshot.get("active_material_layers", 0)
		+ "Projection: %s\n\n" % snapshot.get("projection", "Default")
		+ "Diagnostics:\n- "
		+ "\n- ".join(diagnostics)
	)


func _on_view_selected(index: int) -> void:
	var view_id: int = _view.get_item_id(index)
	terrain.set_debug_view(view_id)


func _on_wireframe_toggled(enabled: bool) -> void:
	terrain.set_debug_wireframe(enabled)
