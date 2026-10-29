extends NucleusAdventureSession
## Route activation through cabin policy before the inherited action transaction.
## Nucleus still owns page state, flags, item costs and pointer hit testing.
signal interaction_requested(id: StringName, destination: StringName)


func _on_hotspot(id: StringName, destination: StringName) -> void:
	interaction_requested.emit(id, destination)
