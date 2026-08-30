# shortcut_manager.gd
# Maps Ctrl/Alt+key shortcuts to viewport action ids. The defaults are editable
# via user://shortcuts.json. Pure data/logic (extends RefCounted) so it can be
# exercised headlessly.

class_name ShortcutManager
extends RefCounted

const DEFAULT_BINDINGS := {
	"mode_select": "Ctrl+1",
	"mode_translate": "Ctrl+2",
	"mode_rotate": "Ctrl+3",
	"toggle_grid": "Ctrl+G",
	"toggle_wireframe": "Ctrl+W",
	"toggle_render": "Ctrl+R",
}

var _bindings: Dictionary = {}


func _init() -> void:
	_bindings = DEFAULT_BINDINGS.duplicate()


func load_from(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for key in parsed:
			if _bindings.has(key):
				_bindings[key] = parsed[key]


func save_to(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_bindings, "\t"))


func get_binding(action: String) -> String:
	return str(_bindings.get(action, ""))


## Return the action id bound to this key event, or "" if none matches.
func match_event(event: InputEventKey) -> String:
	if event == null or event.echo or not event.pressed:
		return ""
	var spec := _event_spec(event)
	if spec.is_empty():
		return ""
	for action in _bindings:
		if str(_bindings[action]) == spec:
			return action
	return ""


func _event_spec(event: InputEventKey) -> String:
	var mods := ""
	if event.ctrl_pressed:
		mods += "Ctrl+"
	if event.alt_pressed:
		mods += "Alt+"
	if event.shift_pressed:
		mods += "Shift+"
	var key_name := OS.get_keycode_string(event.keycode)
	if key_name.is_empty():
		return ""
	return mods + key_name
