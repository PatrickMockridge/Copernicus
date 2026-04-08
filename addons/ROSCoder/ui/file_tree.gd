# file_tree.gd
# Tree-based file browser for workspace

class_name FileTree
extends Control

signal file_selected(path: String)
signal file_right_clicked(path: String, position: Vector2)

var _tree: Tree
var _workspace_path: String = ""


func _init() -> void:
	_tree = Tree.new()
	_tree.set_name("Tree")
	add_child(_tree)

	_tree.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tree.hide_root = false
	_tree.custom_minimum_size.x = 180

	_tree.item_selected.connect(_on_item_selected)
	_tree.gui_input.connect(_on_gui_input)


func _ready() -> void:
	var home = OS.get_environment("HOME")
	_workspace_path = home + "/.ros_workspace"
	refresh()


func refresh() -> void:
	_tree.clear()
	if not DirAccess.dir_exists_absolute(_workspace_path):
		_workspace_path = OS.get_environment("HOME")
	_refresh_tree_recursive(_workspace_path, null)


func _refresh_tree_recursive(dir_path: String, parent_item: TreeItem) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var item_name = dir.get_next()
	while not item_name.is_empty():
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue

		var full_path = dir_path + "/" + item_name
		if dir.current_is_dir():
			var item = _tree.create_item(parent_item)
			item.set_text(0, item_name)
			item.set_metadata(0, full_path)
			item.set_icon(0, _get_folder_icon())
			_refresh_tree_recursive(full_path, item)
		else:
			var item = _tree.create_item(parent_item)
			item.set_text(0, item_name)
			item.set_metadata(0, full_path)
			item.set_icon(0, _get_file_icon())

		item_name = dir.get_next()
	dir.list_dir_end()


func _get_folder_icon() -> Resource:
	return null


func _get_file_icon() -> Resource:
	return null


func _on_item_selected() -> void:
	var item = _tree.get_selected()
	if item:
		var path = item.get_metadata(0)
		if path is String and not path.is_empty():
			var dir = DirAccess.open(path.get_base_dir())
			if dir:
				file_selected.emit(path)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		_on_item_selected()
