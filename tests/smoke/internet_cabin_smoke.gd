extends Node

func _ready() -> void:
	get_tree().create_timer(10.0).timeout.connect(_timed_out)
	call_deferred("_run_smoke")

func _timed_out() -> void:
	push_error("Internet Cabin smoke timed out")
	get_tree().quit(1)

func _run_smoke() -> void:
	var packed := load("res://game/adventure/cabin_demo.tscn") as PackedScene
	if packed == null:
		push_error("Internet Cabin main scene failed to load")
		get_tree().quit(1)
		return
	var instance := packed.instantiate()
	add_child(instance)
	var session: NucleusAdventureSession = instance.session
	if session == null or session.current_page != &"overview_closed":
		push_error("Internet Cabin boot failed")
		get_tree().quit(1)
		return
	var pages: Array[StringName] = [&"desk", &"window", &"back_wall", &"bed",
		&"door_closed", &"door_open", &"porch_open", &"porch_closed"]
	for page_id in pages:
		if session.change_page(page_id) != OK:
			push_error("Unreachable cabin page: " + str(page_id))
			get_tree().quit(1)
			return
	if session.change_page(&"door_closed") != OK or session.activate_hotspot(&"open") != OK:
		push_error("Cabin door opening failed")
		get_tree().quit(1)
		return
	if not session.has_flag(&"door_open") or session.current_page != &"door_open":
		push_error("Cabin door state inconsistent")
		get_tree().quit(1)
		return
	if session.change_page(&"porch_open") != OK or session.activate_hotspot(&"close") != OK:
		push_error("Cabin exterior door closing failed")
		get_tree().quit(1)
		return
	if session.has_flag(&"door_open") or session.current_page != &"porch_closed":
		push_error("Cabin exterior door state inconsistent")
		get_tree().quit(1)
		return
	print("Internet Cabin smoke PASS")
	get_tree().quit(0)
