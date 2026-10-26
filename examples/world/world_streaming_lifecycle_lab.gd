extends Control
## Manual lab for admission, churn, stale completion, and failure handling.

@onready var lifecycle: NucleusWorldStreamLifecycle = $WorldStreamLifecycle
@onready var status: RichTextLabel = $Margin/VBox/Status

var _fail_next_load: bool = false


func _ready() -> void:
	lifecycle.load_requested.connect(_on_load_requested)
	lifecycle.unload_requested.connect(_on_unload_requested)
	lifecycle.region_state_changed.connect(_on_region_state_changed)

	$Margin/VBox/Actions/RouteA.pressed.connect(
		_set_route.bind([&"dock", &"coast", &"island"])
	)
	$Margin/VBox/Actions/RouteB.pressed.connect(
		_set_route.bind([&"island", &"reef", &"cave"])
	)
	$Margin/VBox/Actions/Teleport.pressed.connect(
		_set_route.bind([&"far_harbour"])
	)
	$Margin/VBox/Actions/Clear.pressed.connect(
		_set_route.bind([])
	)
	$Margin/VBox/Actions/FailNext.pressed.connect(
		_arm_next_load_failure
	)
	$Margin/VBox/Actions/Retry.pressed.connect(
		_retry_failed_regions
	)

	_set_route([&"dock", &"coast", &"island"])


func _set_route(region_ids: Array) -> void:
	var error := lifecycle.set_desired_regions(region_ids)

	if error != OK:
		status.text = "Invalid desired set: %s" % error_string(error)
		return

	_refresh_status()


func _on_load_requested(
	region_id: StringName,
	request_token: int,
) -> void:
	_complete_load_later(region_id, request_token)


func _on_unload_requested(
	region_id: StringName,
	request_token: int,
) -> void:
	_complete_unload_later(region_id, request_token)


func _complete_load_later(
	region_id: StringName,
	request_token: int,
) -> void:
	await get_tree().create_timer(0.45).timeout

	if _fail_next_load:
		_fail_next_load = false
		lifecycle.mark_request_failed(
			region_id,
			request_token,
			NucleusWorldStreamLifecycle.Operation.LOAD,
			ERR_CANT_OPEN,
		)
	else:
		lifecycle.mark_loaded(region_id, request_token)

	_refresh_status()


func _complete_unload_later(
	region_id: StringName,
	request_token: int,
) -> void:
	await get_tree().create_timer(0.2).timeout
	lifecycle.mark_unloaded(region_id, request_token)
	_refresh_status()


func _arm_next_load_failure() -> void:
	_fail_next_load = true
	_refresh_status()


func _retry_failed_regions() -> void:
	for region_id: StringName in lifecycle.get_desired_regions():
		if (
			lifecycle.get_region_state(region_id)
			== NucleusWorldStreamLifecycle.RegionState.LOAD_FAILED
		):
			lifecycle.retry_region(region_id)

	for region_id: StringName in lifecycle.get_resident_regions():
		if (
			lifecycle.get_region_state(region_id)
			== NucleusWorldStreamLifecycle.RegionState.UNLOAD_FAILED
		):
			lifecycle.retry_region(region_id)

	_refresh_status()


func _on_region_state_changed(
	_region_id: StringName,
	_state: int,
) -> void:
	_refresh_status()


func _refresh_status() -> void:
	var snapshot := lifecycle.get_debug_snapshot()
	var lines := PackedStringArray()
	lines.append(
		"Desired: %s"
		% str(lifecycle.get_desired_regions())
	)
	lines.append(
		"Resident: %s"
		% str(lifecycle.get_resident_regions())
	)
	lines.append(
		"Loading: %d | Unloading: %d"
		% [
			snapshot["loading"],
			snapshot["unloading"],
		]
	)
	lines.append(
		"Load failures: %d | Unload failures: %d"
		% [
			snapshot["load_failures"],
			snapshot["unload_failures"],
		]
	)
	lines.append(
		"Fail next load: %s"
		% str(_fail_next_load)
	)
	lines.append("Settled: %s" % str(snapshot["settled"]))
	status.text = "\n".join(lines)
