extends Node

func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(_timed_out)
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
	if not instance._arrows.visible or not instance._arrows.get_node("back").visible:
		push_error("Retreat control must always be visible")
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
	await _verify_interaction(instance)
	await _verify_authoring_and_progress(instance)
	if _failures > 0:
		get_tree().quit(1)
		return
	print("Internet Cabin smoke PASS")
	get_tree().quit(0)


var _failures := 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _mouse(viewport_point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = viewport_point
	if pressed:
		get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = viewport_point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _click(instance: Control, uv: Vector2) -> void:
	var screen: NucleusImageScreen = instance.screen
	var local := screen.image_rect().position + uv * screen.image_rect().size
	var point := screen.get_global_transform_with_canvas() * local
	_mouse(point, true)
	_mouse(point, false)
	await get_tree().process_frame


func _verify_interaction(instance: Control) -> void:
	instance.breathing.enabled = false
	instance.breathing.reset_motion()
	await get_tree().process_frame
	await get_tree().process_frame
	var session: NucleusAdventureSession = instance.session
	var pocket: CabinInventory = instance.inventory
	# Test the real Viewport -> GUI -> Nucleus -> cabin policy pipeline.
	for dimensions in [Vector2(1280, 720), Vector2(1448, 1086),
		Vector2(2520, 1080), Vector2(720, 1280)]:
		instance.size = dimensions
		await get_tree().process_frame
		await get_tree().process_frame
		var drawn_size: Vector2 = instance.screen.image_rect().size
		_check(drawn_size.x <= dimensions.x + 1 and drawn_size.y <= dimensions.y + 1,
			"Artwork cropped by stage: " + str(dimensions))
		instance.navigate(&"desk")
		await _click(instance, Vector2(0.36, 0.45))
		_check(session.current_page == &"computer_screen", "Native CRT click: " + str(dimensions))
		await _click(instance, Vector2(0.5, 0.975))
		_check(session.current_page == &"desk", "Native retreat: " + str(dimensions))
	instance.size = get_viewport().get_visible_rect().size
	await get_tree().process_frame
	await get_tree().process_frame
	instance.navigate(&"back_wall")
	await _click(instance, Vector2(0.85, 0.22))
	_check(session.current_page == &"entry_picture", "Native painting click")
	# State aliases must remain symbolic across revisits.
	instance.navigate(&"bed")
	session.set_flag(&"door_open", false)
	instance._route_click(Vector2(0.25, 0.2))
	_check(session.current_page == &"door_closed", "Closed door alias")
	session.set_flag(&"door_open", true)
	instance.navigate(&"bed")
	instance._route_click(Vector2(0.25, 0.2))
	_check(session.current_page == &"door_open", "Revisited door alias must update")
	# A press cannot activate a different page on release.
	instance.navigate(&"desk")
	var screen: NucleusImageScreen = instance.screen
	var origin := screen.get_global_transform_with_canvas() * (
		screen.image_rect().position + Vector2(0.36, 0.45) * screen.image_rect().size)
	_mouse(origin, true)
	instance.navigate(&"back_wall")
	_mouse(origin, false)
	_check(session.current_page == &"back_wall", "Stale press changed page")
	# Empty-handed and wrong-item attempts preserve authoritative state.
	instance.navigate(&"desktop_tower")
	instance._route_click(Vector2(0.4, 0.3))
	_check(not session.has_flag(&"backup_loaded"), "Empty hand bypassed requirement")
	instance._select_item(&"brass_key")
	instance._route_click(Vector2(0.4, 0.3))
	_check(not session.has_flag(&"backup_loaded"), "Wrong object bypassed requirement")
	_check(pocket.storage.has_item(&"brass_key"), "Wrong object was consumed")
	instance._select_item(&"")
	pocket.discard(&"brass_key", &"cabin_shelf")
	_check(pocket.pickup(&"cd_rom"), "CD pickup after freeing a slot")
	instance._select_item(&"cd_rom")
	await _click(instance, Vector2(0.4, 0.3))
	_check(session.has_flag(&"backup_loaded"), "Correct item did not apply Nucleus action")
	_check(not pocket.storage.has_item(&"cd_rom"), "Consumed CD still in inventory")
	_check(not &"cd_rom" in pocket.items_on_page(&"desktop_tower"), "Consumed CD respawned")
	var message: String = instance._hint.text
	instance._process(0.016)
	_check(instance._hint.text == message and message != "", "Feedback vanished next frame")
	instance.navigate(&"bed_close")
	instance._select_item(&"employee_photos")
	await _click(instance, Vector2(0.4, 0.4))
	_check(session.has_flag(&"photos_compared"), "Photo comparison failed")
	_check(pocket.storage.has_item(&"employee_photos"), "Reusable photos consumed")
	instance._select_item(&"employee_photos")
	instance._route_click(Vector2(0.4, 0.4))
	_check(pocket.storage.has_item(&"employee_photos"), "Repeated one-shot consumed item")
	instance._select_item(&"")
	pocket.pickup(&"brass_key")
	instance.navigate(&"cabin_shelf")
	instance._select_item(&"brass_key")
	await _click(instance, Vector2(0.43, 0.10))
	_check(session.has_flag(&"compartment_open"), "Key action failed")
	# Modal blocks actual world clicks, closes without firing the underlying target.
	instance._inspect_item(&"brass_key")
	await _click(instance, Vector2(0.5, 0.975))
	_check(session.current_page == &"cabin_shelf", "Modal click leaked into world")
	instance._close_inspection()
	# Dropped objects have visible, non-overlapping hit areas and remain recoverable.
	pocket.discard(&"brass_key", &"cabin_shelf")
	pocket.discard(&"employee_photos", &"cabin_shelf")
	var key_rect: Array = pocket.world[&"brass_key"]["rect"]
	var photos_rect: Array = pocket.world[&"employee_photos"]["rect"]
	_check(key_rect != photos_rect, "Dropped objects overlap")
	await _click(instance, Vector2(key_rect[0] + 0.06, key_rect[1] + 0.05))
	_check(pocket.storage.has_item(&"brass_key"), "Dropped key cannot be recovered")
	for button in instance._slots.get_children():
		_check(button.size.x <= 64 and button.size.y <= 64, "Inventory icon inflated slot")
	var saved := pocket.capture_state()
	_check(not pocket.restore_state({"inventory": {"stacks": []}, "world": {}}),
		"Malformed snapshot accepted")
	_check(pocket.capture_state() == saved, "Rejected restore mutated inventory")
	instance.navigate(&"desk")
	instance._inspect_item(&"brass_key")
	var modal_page: StringName = session.current_page
	instance.screen.focus_next()
	instance.screen.activate_focused()
	_check(session.current_page == modal_page, "Keyboard bypassed modal")
	instance._close_inspection()
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = instance.screen.get_global_transform_with_canvas() * (
		instance.screen.image_rect().position + instance.screen.image_rect().size * 0.5)
	instance._select_item(&"brass_key")
	get_viewport().push_input(right, true)
	_check(instance._selected_item == &"", "Right click failed to cancel selection")
	_check(session.current_page == &"desk", "Cancel also navigated")
	right.pressed = false
	get_viewport().push_input(right, true)
	# All authored pages have a working fixed retreat, independently of history.
	for id in instance.page_data:
		instance.navigate(id)
		var expected: StringName = instance._fallback_back()
		await _click(instance, Vector2(0.5, 0.975))
		_check(session.current_page == expected, "Native return failed: " + str(id))


func _verify_authoring_and_progress(instance: Control) -> void:
	var session: NucleusAdventureSession = instance.session
	var pocket: CabinInventory = instance.inventory
	instance.navigate(&"computer_screen")
	session.set_flag(&"backup_loaded", false)
	_check(instance.screen.activate(&"backup_log") == ERR_DOES_NOT_EXIST,
		"Hidden log accepts activation")
	session.set_flag(&"backup_loaded", true)
	_check(instance.screen.activate(&"desktop_inspect") == ERR_DOES_NOT_EXIST,
		"Old computer prompt survives state update")
	_check(instance.screen.activate(&"backup_log") == OK, "Unlocked log unavailable")
	# Allocate drops by free space, not catalog order, and prevent overlap with world items.
	for id in pocket.definitions:
		if pocket.storage.has_item(id):
			_check(pocket.discard(id, &"cabin_shelf"), "Drop allocation failed")
	var locations := pocket.items_on_page(&"cabin_shelf")
	for i in locations.size():
		var a: Array = pocket.world[locations[i]]["rect"]
		var first := Rect2(a[0], a[1], a[2], a[3])
		_check(first.end.x <= 1 and first.end.y < 0.935, "Drop escaped image")
		for j in range(i + 1, locations.size()):
			var b: Array = pocket.world[locations[j]]["rect"]
			_check(not first.intersects(Rect2(b[0], b[1], b[2], b[3])), "Drops overlap")
	pocket.pickup(&"brass_key")
	instance._select_item(&"brass_key")
	pocket.discard(&"brass_key", &"desk")
	for button in instance._slots.get_children():
		if button.icon == null:
			_check(button.modulate == Color.WHITE and button.disabled, "Empty pocket state")
	# Save storage is owned by Nucleus; use an isolated slot and clean it afterwards.
	var slot := "cabin_smoke_%d" % Time.get_ticks_usec()
	var snapshot: Dictionary = instance.capture_progress()
	_check(instance.save_progress(slot) == OK, "Native save failed")
	instance.navigate(&"bed")
	session.set_flag(&"backup_loaded", false)
	_check(instance.load_progress(slot) == OK, "Native load failed")
	_check(instance.capture_progress() == snapshot, "Progress round-trip changed state")
	_check(NucleusSave.delete_slot(slot) == OK, "Test save cleanup failed")
	var invalid := snapshot.duplicate(true)
	invalid["adventure"]["page"] = "missing_page"
	_check(instance.restore_progress(invalid) != OK, "Unknown saved page accepted")
	_check(instance.capture_progress() == snapshot, "Rejected load changed live state")
	invalid = snapshot.duplicate(true)
	invalid["items"]["world"][&"brass_key"]["page"] = "missing_page"
	_check(instance.restore_progress(invalid) != OK, "Unknown item location accepted")
	_check(instance.capture_progress() == snapshot, "Bad item location changed live state")
	instance.set_paused(true)
	_check(instance._shader_select.has_focus(), "Pause has no keyboard focus")
	instance.set_paused(false)
	_check(instance.screen.has_focus(), "Resume did not return keyboard focus")

	# Exercise inventory buttons through GUI dispatch rather than helper-only selection.
	pocket.pickup(&"brass_key")
	await get_tree().process_frame
	var pocket_button: Button = instance._slots.get_child(0)
	var center := pocket_button.get_global_transform_with_canvas() * (pocket_button.size * 0.5)
	_mouse(center, true)
	_mouse(center, false)
	await get_tree().process_frame

	_check(instance._inspect_panel.visible, "Pocket GUI click did not open examination")
	var use_button: Button = instance._inspect_panel.get_child(0).get_child(3)
	center = use_button.get_global_transform_with_canvas() * (use_button.size * 0.5)
	_mouse(center, true)
	_mouse(center, false)
	await get_tree().process_frame
	_check(not instance._inspect_panel.visible and instance._selected_item == &"brass_key",
		"Use button did not select and close examination")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	_check(instance._selected_item == &"" and not instance._paused,
		"Escape must cancel selection before pausing")
