extends "res://tests/headless/test_case.gd"


func run() -> Dictionary:
	_test_screenshot_directory()
	_test_screenshot_path()
	_test_invalid_screenshot_extension()
	_test_screenshot_image_save()
	_test_null_viewport_capture()
	return finish()


func _test_screenshot_directory() -> void:
	expect_equal(
		NucleusPaths.screenshots_directory(),
		NucleusPaths.user_data_directory().path_join("screenshots"),
		"Screenshot directory should live under the project user-data path.",
	)


func _test_screenshot_path() -> void:
	var directory: String = NucleusPaths.screenshots_directory()
	var path: String = NucleusWindow.build_screenshot_path(
		directory,
		"steam:shot",
		".png",
	)

	expect_true(
		path.begins_with(
			ProjectSettings.globalize_path(directory).path_join("steam_shot_")
		),
		"Screenshot path should sanitize its filename prefix.",
	)
	expect_true(
		path.ends_with(".png"),
		"Screenshot path should normalize the requested extension.",
	)


func _test_invalid_screenshot_extension() -> void:
	expect_true(
		NucleusWindow.build_screenshot_path(
			"",
			"screenshot",
			"bmp",
		).is_empty(),
		"Unsupported screenshot extensions should be rejected.",
	)


func _test_screenshot_image_save() -> void:
	var directory: String = (
		NucleusPaths.user_data_directory()
		.path_join("nucleus_window_test")
	)
	var path: String = directory.path_join("capture.png")
	var image := Image.create(
		2,
		2,
		false,
		Image.FORMAT_RGB8,
	)
	image.fill(Color(0.25, 0.5, 0.75))

	var error: Error = NucleusWindow.save_screenshot_image(
		image,
		path,
	)

	expect_equal(
		error,
		OK,
		"PNG screenshot Image should save successfully.",
	)
	expect_true(
		FileAccess.file_exists(path),
		"Saved screenshot should exist on disk.",
	)

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)


func _test_null_viewport_capture() -> void:
	expect_true(
		NucleusWindow.capture_viewport(null) == null,
		"Null viewport capture should fail safely.",
	)
