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
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", CopernicusTheme.SPACE_S)
	panel.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	var title := CopernicusTheme.make_heading("Robot Library")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var imp := CopernicusTheme.make_secondary_button("Import URDF/MJCF…")
	imp.pressed.connect(func() -> void: import_requested.emit())
	header.add_child(imp)

	v.add_child(CopernicusTheme.make_separator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	v.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", CopernicusTheme.SPACE_M)
	scroll.add_child(list)

	for cat in RobotLibrary.get_categories():
		list.add_child(CopernicusTheme.make_section(RobotLibrary.get_categories()[cat]))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", CopernicusTheme.SPACE_S)
		grid.add_theme_constant_override("v_separation", CopernicusTheme.SPACE_S)
		list.add_child(grid)
		for d in RobotLibrary.get_definitions():
			if d["category"] == cat:
				grid.add_child(_make_card(d))


func _make_card(d: Dictionary) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(180, 118)
	card.add_theme_stylebox_override("normal", CopernicusTheme.card_background())
	card.add_theme_stylebox_override("hover", CopernicusTheme.card_background())
	card.add_theme_stylebox_override("pressed", CopernicusTheme.card_background())
	card.add_theme_stylebox_override("focus", CopernicusTheme.card_background())
	card.pressed.connect(func() -> void: _on_load(d["id"]))

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", CopernicusTheme.SPACE_XS)
	card.add_child(v)

	var swatch := ColorRect.new()
	swatch.color = d["color"]
	swatch.custom_minimum_size.y = 44
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(swatch)

	var name := Label.new()
	name.text = d["name"]
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.add_theme_color_override("font_color", CopernicusTheme.TEXT_PRIMARY)
	v.add_child(name)

	var desc := Label.new()
	desc.text = d["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	desc.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	v.add_child(desc)

	return card


func _on_load(id: String) -> void:
	if not _workspace:
		return
	var node := RobotLibrary.build(id)
	if node:
		_workspace.load_robot_node(node)
		robot_loaded.emit()
