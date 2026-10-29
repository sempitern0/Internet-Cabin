@tool
extends EditorPlugin

const Parser = preload("res://addons/nucleus_localization/message_parser.gd")
var _parser: EditorTranslationParserPlugin
var _files: EditorFileDialog
var _folder: EditorFileDialog
var _dock: EditorDock
var _summary: Label
var _status: Label
var _search: LineEdit
var _translations: ItemList


func _enter_tree() -> void:
	_parser = Parser.new()
	add_translation_parser_plugin(_parser)
	_files = EditorFileDialog.new()
	_files.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	_files.access = EditorFileDialog.ACCESS_RESOURCES
	_files.filters = PackedStringArray(["*.po,*.mo ; Gettext translations"])
	_files.files_selected.connect(_register)
	_folder = EditorFileDialog.new()
	_folder.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_folder.access = EditorFileDialog.ACCESS_RESOURCES
	_folder.dir_selected.connect(_sources)
	for dialog: Window in [_files, _folder]:
		EditorInterface.get_base_control().add_child(dialog)
	add_tool_menu_item("Nucleus: Register PO/MO translations", _show_files)
	add_tool_menu_item("Nucleus: Add translation source folder", _show_folder)
	_build_dock()
	ProjectSettings.settings_changed.connect(_refresh_dock)


func _exit_tree() -> void:
	remove_tool_menu_item("Nucleus: Register PO/MO translations")
	remove_tool_menu_item("Nucleus: Add translation source folder")
	remove_translation_parser_plugin(_parser)
	if ProjectSettings.settings_changed.is_connected(_refresh_dock):
		ProjectSettings.settings_changed.disconnect(_refresh_dock)
	remove_dock(_dock)
	_dock.queue_free()
	for dialog: Window in [_files, _folder]:
		dialog.queue_free()


func _show_files() -> void:
	_files.popup_centered_ratio(0.6)


func _show_folder() -> void:
	_folder.popup_centered_ratio(0.6)


func _register(paths: PackedStringArray) -> void:
	var error := NucleusLocalizationProjectTools.register_translations(paths)
	_status.text = ("Translations registered in Project Settings."
		if error == OK else "Registration failed: " + error_string(error))
	_refresh_dock()


func _sources(path: String) -> void:
	var error := NucleusLocalizationProjectTools.add_source_folder(path)
	_status.text = ("Sources added. Open Project Settings > Localization > "
		+ "Template Generation, then Generate to create or update your POT."
		if error == OK else "Source registration failed: " + error_string(error))
	_refresh_dock()


func _build_dock() -> void:
	_dock = EditorDock.new()
	_dock.name = "NucleusLocalization"
	_dock.title = "Localization"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock.add_child(column)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary)
	var register_button := Button.new()
	register_button.text = "Register translations…"
	register_button.tooltip_text = "Add PO/MO files without replacing existing translations."
	register_button.pressed.connect(_show_files)
	column.add_child(register_button)
	var sources_button := Button.new()
	sources_button.text = "Add source folder…"
	sources_button.tooltip_text = "Include GD, TSCN and TRES sources in native POT generation."
	sources_button.pressed.connect(_show_folder)
	column.add_child(sources_button)
	_search = LineEdit.new()
	_search.name = "TranslationFilter"
	_search.placeholder_text = "Filter registered paths…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_query: String): _refresh_dock())
	column.add_child(_search)
	_translations = ItemList.new()
	_translations.name = "RegisteredTranslations"
	_translations.custom_minimum_size.y = 160
	_translations.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_translations.item_activated.connect(_reveal_translation)
	column.add_child(_translations)
	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_dock)
	column.add_child(refresh_button)
	_status = Label.new()
	_status.text = "Double-click a translation to reveal it in FileSystem."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var help_label := Label.new()
	help_label.text = "POT: Project Settings → Localization → Template Generation."
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help_label)
	add_dock(_dock)
	_refresh_dock()


func _refresh_dock() -> void:
	if not is_instance_valid(_translations):
		return
	var selected_path := ""
	var selected := _translations.get_selected_items()
	if not selected.is_empty():
		selected_path = str(_translations.get_item_metadata(selected[0]))
	_translations.clear()
	var paths := PackedStringArray(ProjectSettings.get_setting(
		NucleusLocalizationProjectTools.TRANSLATIONS, PackedStringArray()))
	var sources := PackedStringArray(ProjectSettings.get_setting(
		NucleusLocalizationProjectTools.SOURCES, PackedStringArray()))
	_summary.text = "%d translations · %d source files" % [paths.size(), sources.size()]
	for path in paths:
		if not _search.text.is_empty() and not path.to_lower().contains(_search.text.to_lower()):
			continue
		var index := _translations.add_item(path.get_file())
		_translations.set_item_metadata(index, path)
		_translations.set_item_tooltip(index, path)
		if not ResourceLoader.exists(path):
			_translations.set_item_text(index, "Missing: " + path.get_file())
		if path == selected_path:
			_translations.select(index)


func _reveal_translation(index: int) -> void:
	var path := str(_translations.get_item_metadata(index))
	EditorInterface.get_file_system_dock().navigate_to_path(path)
