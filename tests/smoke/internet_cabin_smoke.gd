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
	var pocket: CabinInventory = instance.inventory
	if pocket.storage.max_slots != 2:
		push_error("Cabin pocket capacity must equal two")
		get_tree().quit(1)
		return
	if not pocket.pickup(&"cd_rom") or not pocket.pickup(&"employee_photos"):
		push_error("First two items should fit")
		get_tree().quit(1)
		return
	if pocket.pickup(&"brass_key") or pocket.storage.get_used_slots() != 2:
		push_error("Third item bypassed inventory capacity")
		get_tree().quit(1)
		return
	if not pocket.discard(&"cd_rom", &"desktop_tower"):
		push_error("Discard failed")
		get_tree().quit(1)
		return
	if not pocket.pickup(&"brass_key"):
		push_error("Freed slot cannot accept an item")
		get_tree().quit(1)
		return
	var snapshot := pocket.capture_state()
	pocket.storage.clear()
	pocket.restore_state(snapshot)
	if not pocket.storage.has_item(&"brass_key"):
		push_error("Cabin inventory restore lost item state")
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
	if instance._shader_name != "Fathom":
		push_error("Fathom must be the default adventure shader")
		get_tree().quit(1)
		return
	for detail_page in [&"bed_close", &"bed_windows", &"entry_picture",
		&"desktop_tower", &"computer_screen", &"cabin_shelf",
		&"cabin_clothes", &"cabin_boots"]:
		if session.change_page(detail_page) != OK:
			push_error("Cabin closeup not accessible: " + str(detail_page))
			get_tree().quit(1)
			return
		var back_id: StringName = instance._fallback_back()
		if session.change_page(back_id) != OK:
			push_error("Cabin closeup cannot return: " + str(detail_page))
			get_tree().quit(1)
			return
	if session.change_page(&"overview_closed") != OK:
		push_error("Overview unavailable after closeups")
		get_tree().quit(1)
		return
	# Exercise the same image-coordinate route as real mouse clicks.
	session.change_page(&"desk")
	instance._route_click(Vector2(0.36, 0.45))
	if session.current_page != &"computer_screen":
		push_error("Clicking CRT did not open computer desktop")
		get_tree().quit(1)
		return
	instance._route_click(Vector2(0.50, 0.975))
	if session.current_page != &"desk":
		push_error("Bottom edge did not return from computer desktop")
		get_tree().quit(1)
		return
	session.change_page(&"door_closed")
	instance._route_click(Vector2(0.26, 0.20))
	if session.current_page != &"entry_picture":
		push_error("Clicking doorway painting did not open detail")
		get_tree().quit(1)
		return
	instance._route_click(Vector2(0.50, 0.975))
	if session.current_page != &"door_closed":
		push_error("Painting closeup did not return to doorway")
		get_tree().quit(1)
		return
	session.change_page(&"back_wall")
	instance._route_click(Vector2(0.10, 0.65))
	if session.current_page != &"bed":
		push_error("Clicking bed from opposite wall failed")
		get_tree().quit(1)
		return
	session.change_page(&"window")
	instance._route_click(Vector2(0.50, 0.975))
	if session.current_page != &"desk":
		push_error("Window back route failed")
		get_tree().quit(1)
		return
	session.change_page(&"overview_closed")
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
	if (not instance.page_data[&"desk"].has("edge_left")
		or not instance.page_data[&"desk"].has("edge_right")):
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
