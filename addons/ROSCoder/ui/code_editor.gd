# code_editor.gd
# CodeEdit wrapper with Python syntax highlighting

class_name CodeEditor
extends Control

var _code_edit: CodeEdit
var _current_file: String = ""
var _is_dirty: bool = false
var _status_label: Label


func _init() -> void:
	_code_edit = CodeEdit.new()
	_code_edit.set_name("CodeEdit")
	add_child(_code_edit)

	_code_edit.set_language_for_highlighting("python")
	_code_edit.show_line_numbers = true
	_code_edit.bookmark_enabled = true
	_code_edit.code_folding_enabled = true
	_code_edit.custom_minimum_size.y = 300

	_code_edit.text_changed.connect(_on_text_changed)


func _on_text_changed() -> void:
	_is_dirty = true


func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var content = file.get_as_text()
	file.close()

	_code_edit.text = content
	_current_file = path
	_is_dirty = false
	return true


func save_file() -> bool:
	if _current_file.is_empty():
		return false

	var file = FileAccess.open(_current_file, FileAccess.WRITE)
	if not file:
		return false

	file.store_string(_code_edit.text)
	file.close()
	_is_dirty = false
	return true


func get_content() -> String:
	return _code_edit.text


func set_content(code: String) -> void:
	_code_edit.text = code
	_current_file = ""
	_is_dirty = false


func is_dirty() -> bool:
	return _is_dirty


func get_current_file() -> String:
	return _current_file
