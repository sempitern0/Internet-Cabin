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
	var renderer: NucleusScreenShaderStack = instance.stack
	if renderer.stage_count() != 1 or renderer.get_pass_material(&"vhs") == null:
		push_error("VHS pass not active on initial page")
		get_tree().quit(1)
		return
	var breathing: InternetCabinBreathing = instance.breathing
	if breathing.vertical_amplitude < 0.005:
		push_error("Vertical breathing amplitude is unexpectedly low")
		get_tree().quit(1)
		return
	if session.change_page(&"desk") != OK:
		push_error("Desk page unavailable")
		get_tree().quit(1)
		return
	var pc_region = instance.screen.hotspot_at(Vector2(0.36, 0.45))
	if pc_region == null or pc_region.id != &"screen":
		push_error("CRT interactive polygon does not cover the CRT")
		get_tree().quit(1)
		return
	if session.change_page(&"overview_closed") != OK:
		push_error("Overview unavailable")
		get_tree().quit(1)
		return
	if instance.screen.hotspot_at(Vector2(0.73, 0.78)) != null:
		push_error("Empty floor should not activate a nonexistent bed")
		get_tree().quit(1)
		return
	if instance._arrows.visible:
		push_error("Navigation guides must start hidden")
		get_tree().quit(1)
		return
	instance.set_paused(true)
	if not instance._paused or instance.screen.interaction_enabled:
		push_error("Pause did not lock image interactions")
		get_tree().quit(1)
		return
	instance.set_paused(false)
	if instance._paused or not instance.screen.interaction_enabled:
		push_error("Resume did not restore interactions")
		get_tree().quit(1)
		return
	if not instance.page_data[&"desk"].has("edge_left") or not instance.page_data[&"desk"].has("edge_right"):
		push_error("Desk is missing explicit navigation")
		get_tree().quit(1)
		return
	var pages: Array[StringName] = [&"desk", &"window", &"back_wall", &"bed",
		&"door_closed", &"door_open", &"porch_open", &"porch_closed"]
	for page_id in pages:
		if session.change_page(page_id) != OK:
			push_error("Unreachable cabin page: " + str(page_id))
			get_tree().quit(1)
			return
		# Page transitions must not remove the game-owned VHS filter.
		if renderer.stage_count() != 1:
			push_error("VHS filter disappeared after page transition")
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
