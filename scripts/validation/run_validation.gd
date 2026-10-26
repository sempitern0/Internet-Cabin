extends SceneTree
## Headless entry point for the same validation backend used by Development Tools.
##
## Example:
## godot --headless --path . --script res://scripts/validation/run_validation.gd -- \\
##   --scene=res://examples/validation/gameplay_3d.tscn \\
##   --resource=res://path/to/catalog.tres


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var targets := _parse_targets(OS.get_cmdline_user_args())
	if targets.is_empty():
		push_error(
			"Validation requires at least one --scene=res://... or "
			+ "--resource=res://... target."
		)
		quit(2)
		return

	var issue_count := 0
	for target: Dictionary in targets:
		var kind := str(target.get("kind", ""))
		var path := str(target.get("path", ""))
		var report: Dictionary
		if kind == "scene":
			report = NucleusDevelopmentValidation.validate_scene(path)
		else:
			report = NucleusDevelopmentValidation.validate_resource(path)
		print(NucleusDevelopmentValidation.format_report(report))
		issue_count += int(report.get("issue_count", 0))

	if issue_count > 0:
		push_error("Nucleus validation: FAIL (%d issue(s))." % issue_count)
		quit(1)
		return

	print("Nucleus validation: PASS (%d target(s))." % targets.size())
	quit(0)


func _parse_targets(arguments: PackedStringArray) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for argument: String in arguments:
		if argument.begins_with("--scene="):
			targets.append({
				"kind": "scene",
				"path": argument.trim_prefix("--scene="),
			})
		elif argument.begins_with("--resource="):
			targets.append({
				"kind": "resource",
				"path": argument.trim_prefix("--resource="),
			})
	return targets
