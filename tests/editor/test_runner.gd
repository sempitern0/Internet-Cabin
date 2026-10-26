extends Node
## Editor-friendly launcher for the same dependency-free suites used by CI.

const TEST_MANIFEST := preload("res://tests/headless/test_manifest.gd")


func _ready() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var total_checks: int = 0
	var failures := PackedStringArray()

	for suite_script: Script in TEST_MANIFEST.SUITES:
		var suite: Variant = suite_script.new()
		var result: Dictionary = suite.run()
		total_checks += int(result.get("checks", 0))

		for failure: String in result.get("failures", PackedStringArray()):
			failures.append(
				"%s: %s"
				% [suite_script.resource_path.get_file(), failure]
			)

	var exit_code := 0

	if failures.is_empty():
		print(
			"Nucleus editor tests: PASS (%d checks, %d suites)."
			% [total_checks, TEST_MANIFEST.SUITES.size()]
		)
	else:
		exit_code = 1
		push_error(
			"Nucleus editor tests: FAIL (%d failures / %d checks)."
			% [failures.size(), total_checks]
		)

		for failure: String in failures:
			push_error("  - " + failure)

	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(exit_code)
