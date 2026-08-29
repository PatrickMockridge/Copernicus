# robot_gallery.gd
# Out-of-box robot library: a grid of robot cards grouped by category.

class_name RobotGallery
extends Control

signal import_requested()
signal robot_loaded()

var _workspace: CompositeWorkspace = null


func _ready() -> void:
	_build()


func set_workspace(ws: CompositeWorkspace) -> void:
	_workspace = ws


func _build() -> void:
	var win := UiPanel.new().setup("Robot Library")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)

	var imp := UiButton.new().setup("Import URDF/MJCF…", UiButton.Variant.SECONDARY)
	imp.pressed.connect(func() -> void: import_requested.emit())
	win.title_actions().add_child(imp)

	var v: VBoxContainer = win.body()

	v.add_child(UiSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	v.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", UiTheme.space("m"))
	scroll.add_child(list)

	for cat in RobotLibrary.get_categories():
		list.add_child(UiSection.new().setup(RobotLibrary.get_categories()[cat]))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", UiTheme.space("s"))
		grid.add_theme_constant_override("v_separation", UiTheme.space("s"))
		list.add_child(grid)
		for d in RobotLibrary.get_definitions():
			if d["category"] == cat:
				grid.add_child(_make_card(d))


func _make_card(d: Dictionary) -> Control:
	var card := UiCard.new().setup(d["name"], d["description"], d["color"])
	card.custom_minimum_size = Vector2(180, 118)
	card.pressed.connect(func() -> void: _on_load(d["id"]))
	return card


func _on_load(id: String) -> void:
	if not _workspace:
		return
	var node := RobotLibrary.build(id)
	if node:
		_workspace.load_robot_node(node)
		robot_loaded.emit()
