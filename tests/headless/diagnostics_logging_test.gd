extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_formatter_is_bounded_and_deterministic()
	_test_multiline_depth_limit()
	_test_debug_table()
	_test_log_level_contract()
	_test_file_logger_process_identity()
	return finish()


func _test_formatter_is_bounded_and_deterministic() -> void:
	var payload: Dictionary = {
		"z": [1, 2, 3, 4, 5],
		"a": "abcdefghijklmnopqrstuvwxyz",
		"m": 3.14159265,
	}
	var rendered: String = NucleusLogFormatter.format_compact(
		payload,
		{
			"max_items": 2,
			"max_string_length": 12,
			"float_precision": 2,
		},
	)

	expect_true(
		rendered.begins_with('{"a": "abcdefghi...'),
		"Formatter sorts dictionary keys and truncates long strings.",
	)
	expect_true(
		rendered.contains("... +1"),
		"Formatter reports dictionary entries omitted by the item budget.",
	)

	var array_text: String = NucleusLogFormatter.format_compact(
		[1, 2, 3, 4],
		{"max_items": 2},
	)
	expect_equal(
		array_text,
		"[1, 2, ... +2]",
		"Formatter bounds arrays without hiding how much data was omitted.",
	)


func _test_multiline_depth_limit() -> void:
	var rendered: String = NucleusLogFormatter.format_multiline(
		{
			"outer": {
				"middle": {
					"inner": 42,
				},
			},
		},
		{"max_depth": 2},
	)

	expect_true(
		rendered.contains("{...}"),
		"Formatter stops recursive expansion at the configured depth.",
	)
	expect_true(
		rendered.contains("\n"),
		"Multiline formatting preserves readable nested structure.",
	)


func _test_debug_table() -> void:
	var rows: Array = [
		{
			"region": "island_03",
			"state": "LOADED",
			"progress": 1.0,
		},
		{
			"region": "island_04",
			"state": "LOADING",
			"progress": 0.625,
		},
		{
			"region": "island_05",
			"state": "UNLOADED",
			"progress": 0.0,
		},
	]
	var table: String = NucleusDebugTable.format(
		rows,
		["region", "state", "progress"],
		16,
		2,
	)

	expect_true(
		table.contains("region"),
		"Debug table includes explicit column labels.",
	)
	expect_true(
		table.contains("island_03"),
		"Debug table formats dictionary rows.",
	)
	expect_true(
		table.contains("... 1 more row(s)"),
		"Debug table bounds row count and reports omitted rows.",
	)


func _test_log_level_contract() -> void:
	var original_level: int = NucleusLog.get_minimum_level()
	var original_callsite: bool = NucleusLog.get_include_callsite()

	expect_equal(
		NucleusLog.set_minimum_level(NucleusLog.Level.ERROR),
		OK,
		"Logging facade accepts a valid minimum level.",
	)
	expect_false(
		NucleusLog.is_level_enabled(NucleusLog.Level.INFO),
		"Info output can be disabled by minimum verbosity.",
	)
	expect_true(
		NucleusLog.is_level_enabled(NucleusLog.Level.WARNING),
		"Warnings remain enabled even at the strictest minimum level.",
	)
	expect_true(
		NucleusLog.is_level_enabled(NucleusLog.Level.ERROR),
		"Errors remain enabled even at the strictest minimum level.",
	)
	expect_equal(
		NucleusLog.set_minimum_level(999),
		ERR_INVALID_PARAMETER,
		"Invalid logging levels are rejected.",
	)

	NucleusLog.set_include_callsite(true)
	expect_true(
		NucleusLog.get_include_callsite(),
		"Call-site decoration is an explicit opt-in.",
	)

	NucleusLog.set_include_callsite(original_callsite)
	NucleusLog.set_minimum_level(original_level)


func _test_file_logger_process_identity() -> void:
	var directory_path: String = (
		"user://nucleus_diagnostics_test_%d"
		% Time.get_ticks_usec()
	)
	var logger: NucleusFileLogger = NucleusFileLogger.new(directory_path)

	expect_true(
		logger.is_ready(),
		"File logger should open an isolated test log.",
	)

	logger.close()

	var directory: DirAccess = DirAccess.open(directory_path)

	expect_true(
		directory != null,
		"File logger should create its configured log directory.",
	)

	if directory == null:
		return

	var log_files: PackedStringArray = directory.get_files()

	expect_equal(
		log_files.size(),
		1,
		"Isolated file logger should create exactly one runtime log.",
	)

	if not log_files.is_empty():
		var file_name: String = log_files[0]
		var log_path: String = directory_path.path_join(file_name)
		var contents: String = FileAccess.get_file_as_string(log_path)

		expect_true(
			file_name.contains(
				"_pid-%d_" % OS.get_process_id()
			),
			"Runtime log filename includes the process ID.",
		)
		expect_true(
			contents.contains(
				"# Process ID: %d" % OS.get_process_id()
			),
			"Runtime log header includes the process ID.",
		)

	for file_name: String in log_files:
		directory.remove(file_name)

	directory = null

	if DirAccess.dir_exists_absolute(directory_path):
		DirAccess.remove_absolute(directory_path)
