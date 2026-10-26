extends Node

const REQUIRED_AUTOLOADS := [
	"NucleusApp",
	"NucleusSettings",
	"NucleusInput",
	"NucleusAudio",
	"NucleusSave",
	"NucleusSceneFlow",
]


func _ready() -> void:
	var failures := PackedStringArray()
	var version := Engine.get_version_info()

	if int(version.get("major", 0)) != 4:
		failures.append("Expected Godot major version 4.")

	if int(version.get("minor", 0)) < 7:
		failures.append("Expected Godot 4.7.x or newer within the 4.x line.")

	for autoload_name: String in REQUIRED_AUTOLOADS:
		if get_node_or_null("/root/" + autoload_name) == null:
			failures.append("Missing required Autoload: " + autoload_name)

	if failures.is_empty():
		print("Nucleus smoke scene: PASS.")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("Nucleus smoke scene: " + failure)

	get_tree().quit(1)
