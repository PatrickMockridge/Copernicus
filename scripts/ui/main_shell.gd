# main_shell.gd
# IDE-style shell (VS Code for robots): activity bar + side bar + editor tabs +
# bottom terminal panel + status bar, with a command palette (Ctrl+Shift+P).

class_name MainShell
extends Control

const CompositeWorkspace = preload("res://scripts/composite_workspace.gd")
const AiAssistantPanel = preload("res://scripts/main.gd")
const MarketplacePanel = preload("res://scripts/marketplace/ui/marketplace_panel.gd")
const WalletPanel = preload("res://scripts/rchain/ui/wallet_panel.gd")
const CoordinationPanel = preload("res://scripts/rchain/ui/coordination_panel.gd")
const RobotGallery = preload("res://scripts/robots/ui/robot_gallery.gd")
const RaasLauncher = preload("res://scripts/rchain/ui/raas_launcher.gd")
const DemoHost = preload("res://scripts/ui/demo_host.gd")
const VcsPanel = preload("res://scripts/vcs/ui/vcs_panel.gd")

enum MenuId {
	FILE_OPEN, FILE_RECENT, FILE_EXIT,
	VIEW_RESET, VIEW_WIREFRAME, VIEW_GRID, VIEW_DOMAIN, VIEW_TERMINAL,
	SENSOR_LIDAR, SENSOR_CAMERA, SENSOR_IMU,
	TOOL_IK, TOOL_PHYSICS, TOOL_NAV, TOOL_GPU, TOOL_OMNI, TOOL_INDUSTRIAL, TOOL_ROS2,
	TOOL_PHYSICS_DEMO, TOOL_TURTLE_DEMO,
	HELP_ABOUT,
}

const ACTIVITY_SPECS := [
	["viewer", "▦", "Viewer", "design"],
	["robots", "◧", "Robots", "design"],
	["vcs", "⇅", "Version Control", "design"],
	["marketplace", "◫", "Marketplace", "publish"],
	["wallet", "◈", "Wallet", "publish"],
	["coordination", "◍", "Coordination", "publish"],
	["raas", "▸", "RaaS", "operate"],
	["extensions", "◇", "Extensions", "utility"],
]

var _workspace: CompositeWorkspace
var _panels: Dictionary = {}          # id -> Control (editor panel instances)
var _tabs: Array = []                 # [{id, title, panel}]
var _activity_buttons: Dictionary = {}  # id -> Button

var _side_bar: PanelContainer
var _side_title: Label
var _side_content: Control
var _tab_bar: TabBar
var _editor_content: Control
var _panel_host: PanelContainer
var _terminal_output: TextEdit
var _terminal_input: LineEdit
var _status_left: HBoxContainer
var _status_right: HBoxContainer
var _status_wallet: Label
var _status_node: Label
var _status_ros2: Label
var _status_mode: Label
var _fps_label: Label

var _file_dialog: FileDialog
var _recent_menu: PopupMenu
var _context_menu: PopupMenu
var _view_menu: PopupMenu
var _sensors_menu: PopupMenu
var _command_palette: CommandPalette

var _last_dir: String = ""
var _recent_robots: Array = []
var _current_activity: String = "viewer"
var _overlay: Control = null
var _ros2_connected: bool = false


func _ready() -> void:
	_load_persisted()
	_setup_ui()
	_setup_panels()
	_register_commands()
	_setup_ros2()
	_select_activity("viewer")
	_check_node_async()


func _setup_ros2() -> void:
	var ros2 = get_node_or_null("/root/GodotROS2")
	if ros2 and ros2.has_signal("initialization_completed"):
		ros2.initialization_completed.connect(func(success: bool) -> void: _ros2_connected = success)


func _check_node_async() -> void:
	var rchain = get_node_or_null("/root/RChainService")
	if rchain and rchain.node and rchain.has_method("run_async"):
		rchain.run_async(func() -> Variant: return rchain.node.get_status(), _on_node_checked)


func _on_node_checked(r) -> void:
	if not _status_node:
		return
	if r != null and r.is_ok():
		_status_node.text = "node: ✓"
	else:
		_status_node.text = "node: offline"


func _load_persisted() -> void:
	var f := FileAccess.open("user://last_robot_dir.txt", FileAccess.READ)
	if f:
		_last_dir = f.get_as_text().strip_edges()
	var rf := FileAccess.open("user://recent_robots.json", FileAccess.READ)
	if rf:
		var parsed = JSON.parse_string(rf.get_as_text())
		if parsed is Array:
			_recent_robots = parsed


func _save_persisted() -> void:
	var f := FileAccess.open("user://last_robot_dir.txt", FileAccess.WRITE)
	if f:
		f.store_string(_last_dir)
	var rf := FileAccess.open("user://recent_robots.json", FileAccess.WRITE)
	if rf:
		rf.store_string(JSON.stringify(_recent_robots))


# ---------------------------------------------------------------- UI build

func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.color("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_setup_menu_bar(root)

	root.add_child(_build_spine())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	body.add_child(_build_activity_bar())

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	body.add_child(center)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	center.add_child(mid)

	mid.add_child(_build_side_bar())
	mid.add_child(_build_editor_group())

	center.add_child(_build_panel_host())

	root.add_child(_build_status_bar())

	_setup_file_dialog()
	_setup_context_menu()


func _build_spine() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var brief := UiBrief.new().configure()
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(brief)
	v.add_child(UiStageRail.new().setup())
	return v


func _build_activity_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.x = 48
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("panel")
	sb.border_width_right = 1
	sb.border_color = UiTheme.color("border")
	bar.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.space("xs"))
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_child(v)

	var last_mode := ""
	for spec in ACTIVITY_SPECS:
		if last_mode != "" and spec[3] != last_mode:
			var sep := ColorRect.new()
			sep.custom_minimum_size = Vector2(32, 1)
			sep.color = UiTheme.color("border")
			v.add_child(sep)
		last_mode = spec[3]
		var btn := Button.new()
		btn.text = spec[1]
		btn.tooltip_text = "%s — %s" % [spec[2], spec[3]]
		btn.flat = true
		btn.custom_minimum_size = Vector2(40, 40)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_select_activity.bind(spec[0]))
		v.add_child(btn)
		_activity_buttons[spec[0]] = btn

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	return bar


func _build_side_bar() -> Control:
	_side_bar = PanelContainer.new()
	_side_bar.custom_minimum_size.x = 250
	_side_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_bar.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("panel")
	sb.border_width_right = 1
	sb.border_color = UiTheme.color("border")
	_side_bar.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_side_bar.add_child(v)

	var tb := UiTitleBar.new().setup("")
	_side_title = tb.label()
	_side_title.add_theme_color_override("font_color", UiTheme.color("text"))
	v.add_child(tb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UiTheme.space("m"))
	margin.add_theme_constant_override("margin_right", UiTheme.space("m"))
	margin.add_theme_constant_override("margin_top", UiTheme.space("m"))
	margin.add_theme_constant_override("margin_bottom", UiTheme.space("m"))
	v.add_child(margin)
	_side_content = Control.new()
	_side_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_side_content)

	return _side_bar


func _build_editor_group() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)

	_tab_bar = TabBar.new()
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_tab_bar.tab_close_pressed.connect(_on_tab_close)
	v.add_child(_tab_bar)

	_editor_content = Control.new()
	_editor_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_editor_content)

	return v


func _build_panel_host() -> Control:
	var win := UiPanel.new().setup("Terminal")
	_panel_host = win
	_panel_host.custom_minimum_size.y = 140
	_panel_host.visible = false

	var v: VBoxContainer = win.body()

	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.pressed.connect(func() -> void: _panel_host.visible = false)
	win.title_actions().add_child(close)

	_terminal_output = TextEdit.new()
	_terminal_output.editable = false
	_terminal_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if UiTheme.font("mono"):
		_terminal_output.add_theme_font_override("font", UiTheme.font("mono"))
	v.add_child(_terminal_output)

	_terminal_input = LineEdit.new()
	_terminal_input.placeholder_text = "> command"
	if UiTheme.font("mono"):
		_terminal_input.add_theme_font_override("font", UiTheme.font("mono"))
	_terminal_input.text_submitted.connect(_on_terminal_submit)
	v.add_child(_terminal_input)

	return _panel_host


func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = 28
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("panel")
	sb.border_width_top = 1
	sb.border_color = UiTheme.color("border")
	sb.content_margin_left = UiTheme.space("m")
	sb.content_margin_right = UiTheme.space("m")
	bar.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.space("m"))
	bar.add_child(h)

	_status_left = HBoxContainer.new()
	_status_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_left.add_theme_constant_override("separation", UiTheme.space("m"))
	h.add_child(_status_left)

	_status_wallet = _status_item("wallet")
	_status_left.add_child(_status_wallet)
	_status_node = _status_item("node")
	_status_left.add_child(_status_node)
	_status_ros2 = _status_item("ros2")
	_status_left.add_child(_status_ros2)
	_status_mode = _status_item("mode")
	_status_left.add_child(_status_mode)

	_status_right = HBoxContainer.new()
	h.add_child(_status_right)
	var term_btn := Button.new()
	term_btn.text = "Terminal"
	term_btn.flat = true
	term_btn.pressed.connect(_toggle_terminal)
	_status_right.add_child(term_btn)
	_fps_label = UiLabel.new().setup("0 fps", UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
	_status_right.add_child(_fps_label)

	return bar


func _status_item(name: String) -> Label:
	var label := UiLabel.new().setup("%s: —" % name, UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
	label.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	label.add_theme_color_override("font_color", UiTheme.color("text"))
	return label


func _setup_menu_bar(root: VBoxContainer) -> void:
	var menu_bar := MenuBar.new()
	root.add_child(menu_bar)

	var file_menu := PopupMenu.new()
	file_menu.name = "File"
	file_menu.add_item("Open Robot…", MenuId.FILE_OPEN)
	_recent_menu = PopupMenu.new()
	_recent_menu.name = "Open Recent"
	file_menu.add_child(_recent_menu)
	file_menu.add_submenu_item("Open Recent", "Open Recent")
	file_menu.add_separator()
	file_menu.add_item("Exit", MenuId.FILE_EXIT)
	file_menu.id_pressed.connect(_on_menu_pressed)
	_recent_menu.index_pressed.connect(_on_recent_index)
	menu_bar.add_child(file_menu)
	_rebuild_recent_menu()

	_view_menu = PopupMenu.new()
	_view_menu.name = "View"
	menu_bar.add_child(_view_menu)

	_sensors_menu = PopupMenu.new()
	_sensors_menu.name = "Sensors"
	_sensors_menu.add_check_item("Lidar", MenuId.SENSOR_LIDAR)
	_sensors_menu.add_check_item("Camera Frustum", MenuId.SENSOR_CAMERA)
	_sensors_menu.add_check_item("IMU Axes", MenuId.SENSOR_IMU)
	_sensors_menu.id_pressed.connect(_on_menu_pressed)
	_view_menu.add_child(_sensors_menu)

	_view_menu.add_item("Reset View", MenuId.VIEW_RESET)
	_view_menu.add_separator()
	_view_menu.add_check_item("Wireframe", MenuId.VIEW_WIREFRAME)
	_view_menu.add_check_item("Grid", MenuId.VIEW_GRID)
	_view_menu.set_item_checked(_view_menu.get_item_index(MenuId.VIEW_GRID), true)
	_view_menu.add_check_item("Domain Randomization", MenuId.VIEW_DOMAIN)
	_view_menu.add_separator()
	_view_menu.add_submenu_item("Sensors", "Sensors")
	_view_menu.add_separator()
	_view_menu.add_check_item("Terminal", MenuId.VIEW_TERMINAL)
	_view_menu.id_pressed.connect(_on_menu_pressed)

	var tools_menu := PopupMenu.new()
	tools_menu.name = "Tools"
	tools_menu.add_item("Inverse Kinematics…", MenuId.TOOL_IK)
	tools_menu.add_item("Physics Backend…", MenuId.TOOL_PHYSICS)
	tools_menu.add_item("Navigation…", MenuId.TOOL_NAV)
	tools_menu.add_item("GPU / RL Training…", MenuId.TOOL_GPU)
	tools_menu.add_item("Omniverse / USD…", MenuId.TOOL_OMNI)
	tools_menu.add_item("Industrial Backends…", MenuId.TOOL_INDUSTRIAL)
	tools_menu.add_separator()
	tools_menu.add_item("ROS2 Connect", MenuId.TOOL_ROS2)
	tools_menu.add_separator()
	tools_menu.add_item("Physics Demo", MenuId.TOOL_PHYSICS_DEMO)
	tools_menu.add_item("Turtle Demo", MenuId.TOOL_TURTLE_DEMO)
	tools_menu.id_pressed.connect(_on_menu_pressed)
	menu_bar.add_child(tools_menu)

	var help_menu := PopupMenu.new()
	help_menu.name = "Help"
	help_menu.add_item("About", MenuId.HELP_ABOUT)
	help_menu.id_pressed.connect(_on_menu_pressed)
	menu_bar.add_child(help_menu)


func _setup_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.urdf, *.mjcf ; Robot model"])
	_file_dialog.current_dir = _default_open_dir()
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


func _default_open_dir() -> String:
	if not _last_dir.is_empty() and DirAccess.dir_exists_absolute(_last_dir):
		return _last_dir
	var home := OS.get_environment("HOME")
	if not home.is_empty() and DirAccess.dir_exists_absolute(home):
		return home
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)


func _setup_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Load Robot…", MenuId.FILE_OPEN)
	_context_menu.add_separator()
	_context_menu.add_item("Reset View", MenuId.VIEW_RESET)
	_context_menu.add_check_item("Wireframe", MenuId.VIEW_WIREFRAME)
	_context_menu.add_check_item("Grid", MenuId.VIEW_GRID)
	_context_menu.set_item_checked(_context_menu.get_item_index(MenuId.VIEW_GRID), true)
	_context_menu.add_check_item("Lidar", MenuId.SENSOR_LIDAR)
	_context_menu.add_check_item("Camera Frustum", MenuId.SENSOR_CAMERA)
	_context_menu.add_check_item("IMU Axes", MenuId.SENSOR_IMU)
	_context_menu.add_check_item("Domain Randomization", MenuId.VIEW_DOMAIN)
	_context_menu.id_pressed.connect(_on_menu_pressed)
	add_child(_context_menu)


# ---------------------------------------------------------------- panels

func _setup_panels() -> void:
	_workspace = CompositeWorkspace.new()
	_add_panel("viewer", "Viewer", _workspace)
	_workspace.publish_requested.connect(_on_publish_requested)
	var robot_viewer = _workspace.get_robot_viewer()
	if robot_viewer:
		robot_viewer.context_menu_requested.connect(_on_context_menu_requested)
		robot_viewer.robot_loaded.connect(_on_robot_loaded_for_scenario)

	var ai = AiAssistantPanel.new()
	_add_panel("ai", "AI Assistant", ai)
	if robot_viewer:
		ai.set_viewer(robot_viewer)

	var marketplace = MarketplacePanel.new()
	_add_panel("marketplace", "Marketplace", marketplace)
	marketplace.closed.connect(func() -> void: _select_activity("viewer"))

	_add_panel("wallet", "Wallet", WalletPanel.new())
	_add_panel("coordination", "Coordination", CoordinationPanel.new())

	var gallery = RobotGallery.new()
	gallery.set_workspace(_workspace)
	gallery.import_requested.connect(_open_file_dialog)
	gallery.robot_loaded.connect(func() -> void: _select_activity("viewer"))
	_add_panel("robots", "Robots", gallery)

	_add_panel("vcs", "Version Control", VcsPanel.new())

	var raas = RaasLauncher.new()
	raas.demo_requested.connect(_on_raas_demo_requested)
	_add_panel("raas", "RaaS", raas)

	_add_panel("extensions", "Extensions", _build_extensions_panel())


func _on_robot_loaded_for_scenario(_node: Node3D) -> void:
	var svc = get_node_or_null("/root/ScenarioService")
	if svc:
		svc.context["robot_loaded"] = true
		svc.reevaluate()


func _on_publish_requested(robot_name: String) -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	var panel = PublishPanel.show_for_robot(robot_name)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_content.add_child(panel)
	_overlay = panel
	panel.tree_exited.connect(func() -> void: _overlay = null)


func _add_panel(id: String, title: String, panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_content.add_child(panel)
	panel.visible = false
	_panels[id] = panel
	_tabs.append({"id": id, "title": title, "panel": panel})
	_tab_bar.add_tab(title)


func _build_extensions_panel() -> Control:
	var win := UiPanel.new().setup("Extensions")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v: VBoxContainer = win.body()
	v.add_child(UiLabel.new().setup("Modules contribute commands, views and status items. Registered via ModuleRegistry._static_init.", UiLabel.Kind.BODY, UiLabel.Tone.MUTED))
	v.add_child(UiSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for cat in ModuleRegistry.get_all_categories():
		list.add_child(UiSection.new().setup(str(cat)))
		for mod in ModuleRegistry.get_available(cat):
			list.add_child(_extensions_row(mod))
	return win


func _extensions_row(mod: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.space("s"))
	var name := Label.new()
	name.text = str(mod.get("name", mod.get("id", "?")))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", UiTheme.color("text"))
	row.add_child(name)
	var avail := Label.new()
	avail.text = "●" if mod.get("available", false) else "○"
	avail.add_theme_color_override("font_color", UiTheme.color("success") if mod.get("available", false) else UiTheme.color("text_faint"))
	row.add_child(avail)
	return row


# ---------------------------------------------------------------- navigation

func _select_activity(id: String) -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	_current_activity = id
	for key in _activity_buttons:
		_activity_buttons[key].add_theme_color_override("font_color", UiTheme.color("accent") if key == id else UiTheme.color("text"))
	_show_side_for(id)
	_focus_tab(id)


func _on_raas_demo_requested(scene_path: String) -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	var demo = load(scene_path).instantiate()
	demo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_content.add_child(demo)
	_overlay = demo
	if demo.has_signal("closed"):
		demo.closed.connect(func() -> void: _overlay = null)


func _show_side_for(id: String) -> void:
	match id:
		"viewer":
			_side_bar.visible = true
			_side_title.text = "Workspace"
			_clear_side()
			var info := UiLabel.new().setup("No robot loaded", UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
			var viewer = _workspace.get_robot_viewer()
			if viewer and viewer.get_robot_root():
				info.text = "%s — %d joints" % [viewer.get_robot_root().name, viewer.get_joint_count()]
			_side_content.add_child(info)
		"extensions":
			_side_bar.visible = true
			_side_title.text = "Extensions"
			_clear_side()
			_side_content.add_child(_build_extensions_panel())
		_:
			_side_bar.visible = false


func _clear_side() -> void:
	for child in _side_content.get_children():
		child.queue_free()


func _focus_tab(id: String) -> void:
	for i in range(_tabs.size()):
		if _tabs[i]["id"] == id:
			_tab_bar.current_tab = i
			_apply_tab(i)
			return


func _on_tab_changed(index: int) -> void:
	_apply_tab(index)


func _apply_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	for i in range(_tabs.size()):
		_tabs[i]["panel"].visible = (i == index)


func _on_tab_close(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	var id: String = _tabs[index]["id"]
	if id in ["viewer", "ai", "robots", "vcs", "marketplace", "wallet", "coordination", "raas", "extensions"]:
		return  # primary destinations stay open
	_tab_bar.remove_tab(index)
	_tabs.remove_at(index)


# ---------------------------------------------------------------- commands

func _register_commands() -> void:
	_reg("view.open", "Viewer: Open Workspace", "View", func() -> void: _select_activity("viewer"))
	_reg("robots.open", "Robots: Open Library", "View", func() -> void: _select_activity("robots"))
	_reg("vcs.open", "Version Control: Open", "View", func() -> void: _select_activity("vcs"))
	_reg("marketplace.open", "Marketplace: Open", "View", func() -> void: _select_activity("marketplace"))
	_reg("wallet.open", "Wallet: Open", "View", func() -> void: _select_activity("wallet"))
	_reg("coordination.open", "Coordination: Open", "View", func() -> void: _select_activity("coordination"))
	_reg("raas.open", "RaaS: Open Demos", "View", func() -> void: _select_activity("raas"))
	_reg("extensions.open", "Extensions: List Modules", "View", func() -> void: _select_activity("extensions"))
	_reg("ai.open", "AI Assistant: Open", "View", func() -> void: _focus_tab("ai"))

	_reg("robot.open", "Open Robot…", "File", func() -> void: _open_file_dialog())
	_reg("view.reset", "View: Reset", "View", func() -> void: _workspace.get_robot_viewer().reset_view())
	_reg("view.wireframe", "View: Toggle Wireframe", "View", _toggle_wireframe)
	_reg("view.grid", "View: Toggle Grid", "View", _toggle_grid)
	_reg("view.domain", "View: Toggle Domain Randomization", "View", _toggle_domain)
	_reg("view.terminal", "View: Toggle Terminal", "View", _toggle_terminal)
	_reg("sensor.lidar", "Sensors: Toggle Lidar", "View", _toggle_lidar)
	_reg("sensor.camera", "Sensors: Toggle Camera Frustum", "View", _toggle_camera)
	_reg("sensor.imu", "Sensors: Toggle IMU Axes", "View", _toggle_imu)

	_reg("tool.ik", "Tools: Inverse Kinematics…", "Tools", func() -> void: _open_selector("res://scenes/ik_selector.tscn"))
	_reg("tool.physics", "Tools: Physics Backend…", "Tools", func() -> void: _open_selector("res://scenes/physics_selector.tscn"))
	_reg("tool.nav", "Tools: Navigation…", "Tools", func() -> void: _open_selector("res://scenes/nav_selector.tscn"))
	_reg("tool.gpu", "Tools: GPU / RL Training…", "Tools", func() -> void: _open_selector("res://scenes/gpu/gpu_backend_selector.tscn"))
	_reg("tool.omni", "Tools: Omniverse / USD…", "Tools", func() -> void: _open_selector("res://scenes/omni_selector.tscn"))
	_reg("tool.industrial", "Tools: Industrial Backends…", "Tools", func() -> void: _open_selector("res://scenes/industrial_selector.tscn"))
	_reg("tool.ros2", "Tools: Connect ROS2", "Tools", _connect_ros2)

	_reg("demo.physics", "Demo: Physics (WASD)", "Demo", func() -> void: _open_demo("res://scenes/physics_demo.tscn"))
	_reg("demo.turtle", "Demo: Turtle", "Demo", func() -> void: _open_demo("res://scenes/turtle_demo.tscn"))

	_reg("help", "Help: List Commands", "Terminal", _terminal_help)
	_reg("clear", "Terminal: Clear", "Terminal", _terminal_clear)

	# Plugin-contributed commands (modules registered via ModuleRegistry).
	for cmd in ModuleRegistry.get_contributed_commands():
		if cmd is Dictionary and cmd.has("id") and cmd.has("handler"):
			CommandRegistry.register(cmd)


func _reg(id: String, label: String, category: String, handler: Callable) -> void:
	CommandRegistry.register({"id": id, "label": label, "category": category, "description": label, "keywords": label, "handler": handler})


func _open_file_dialog() -> void:
	_file_dialog.current_dir = _default_open_dir()
	_file_dialog.popup_centered()


func _open_palette() -> void:
	if _command_palette and is_instance_valid(_command_palette):
		return
	_command_palette = CommandPalette.new()
	add_child(_command_palette)


# ---------------------------------------------------------------- menu dispatch

func _on_menu_pressed(id: int) -> void:
	match id:
		MenuId.FILE_OPEN:
			_open_file_dialog()
		MenuId.FILE_EXIT:
			get_tree().quit()
		MenuId.VIEW_RESET:
			_workspace.get_robot_viewer().reset_view()
		MenuId.VIEW_WIREFRAME:
			_workspace.get_robot_viewer().set_show_debug(_toggle(_view_menu, MenuId.VIEW_WIREFRAME))
		MenuId.VIEW_GRID:
			_workspace.get_robot_viewer().set_grid_visible(_toggle(_view_menu, MenuId.VIEW_GRID))
		MenuId.VIEW_DOMAIN:
			_workspace.set_domain_randomization(_toggle(_view_menu, MenuId.VIEW_DOMAIN))
		MenuId.VIEW_TERMINAL:
			_toggle_terminal()
		MenuId.SENSOR_LIDAR:
			_workspace.set_lidar_visible(_toggle(_sensors_menu, MenuId.SENSOR_LIDAR))
		MenuId.SENSOR_CAMERA:
			_workspace.set_camera_visible(_toggle(_sensors_menu, MenuId.SENSOR_CAMERA))
		MenuId.SENSOR_IMU:
			_workspace.set_imu_visible(_toggle(_sensors_menu, MenuId.SENSOR_IMU))
		MenuId.TOOL_IK:
			_open_selector("res://scenes/ik_selector.tscn")
		MenuId.TOOL_PHYSICS:
			_open_selector("res://scenes/physics_selector.tscn")
		MenuId.TOOL_NAV:
			_open_selector("res://scenes/nav_selector.tscn")
		MenuId.TOOL_GPU:
			_open_selector("res://scenes/gpu/gpu_backend_selector.tscn")
		MenuId.TOOL_OMNI:
			_open_selector("res://scenes/omni_selector.tscn")
		MenuId.TOOL_INDUSTRIAL:
			_open_selector("res://scenes/industrial_selector.tscn")
		MenuId.TOOL_ROS2:
			_connect_ros2()
		MenuId.TOOL_PHYSICS_DEMO:
			_open_demo("res://scenes/physics_demo.tscn", "Physics Demo")
		MenuId.TOOL_TURTLE_DEMO:
			_open_demo("res://scenes/turtle_demo.tscn", "Turtle Demo")
		MenuId.HELP_ABOUT:
			Toast.show_toast(self, "Copernicus — Robot Design Interface", Toast.Level.INFO)


func _toggle(menu: PopupMenu, id: int) -> bool:
	var idx := menu.get_item_index(id)
	menu.toggle_item_checked(idx)
	return menu.is_item_checked(idx)


func _toggle_wireframe() -> void:
	var v := _workspace.get_robot_viewer()
	if v:
		v.set_show_debug(not v.is_show_debug())

func _toggle_grid() -> void:
	var v := _workspace.get_robot_viewer()
	if v:
		v.set_grid_visible(not v.is_grid_visible())

func _toggle_domain() -> void:
	_workspace.set_domain_randomization(not _workspace.is_domain_randomization_enabled())

func _toggle_lidar() -> void:
	_workspace.set_lidar_visible(not _workspace.is_lidar_visible())

func _toggle_camera() -> void:
	_workspace.set_camera_visible(not _workspace.is_camera_visible())

func _toggle_imu() -> void:
	_workspace.set_imu_visible(not _workspace.is_imu_visible())

func _toggle_terminal() -> void:
	_panel_host.visible = not _panel_host.visible
	if _panel_host.visible:
		_terminal_input.grab_focus()


# ---------------------------------------------------------------- file / demos

func _on_file_selected(path: String) -> void:
	if path.ends_with(".urdf") or path.ends_with(".mjcf"):
		_last_dir = path.get_base_dir()
		if not _recent_robots.has(path):
			_recent_robots.push_front(path)
			if _recent_robots.size() > 10:
				_recent_robots.resize(10)
		_save_persisted()
		_rebuild_recent_menu()
		if path.ends_with(".mjcf"):
			_workspace.load_mjcf(path)
		else:
			_workspace.load_urdf(path)
		_select_activity("viewer")
	else:
		Toast.show_toast(self, "Unsupported file type", Toast.Level.WARNING)


func _rebuild_recent_menu() -> void:
	if not _recent_menu:
		return
	_recent_menu.clear()
	if _recent_robots.is_empty():
		_recent_menu.add_item("(empty)")
		_recent_menu.set_item_disabled(0, true)
	for path in _recent_robots:
		_recent_menu.add_item(path)


func _on_recent_index(index: int) -> void:
	if index >= 0 and index < _recent_robots.size():
		_on_file_selected(_recent_robots[index])


func _open_demo(scene_path: String, title: String = "") -> void:
	if title.is_empty():
		title = scene_path.get_file().get_basename().capitalize().replace("_", " ")
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	var host = DemoHost.new()
	host.setup(scene_path, title)
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_content.add_child(host)
	_overlay = host
	host.closed.connect(func() -> void: _overlay = null)


func _open_selector(scene_path: String) -> void:
	var selector = load(scene_path).instantiate()
	add_child(selector)


func _connect_ros2() -> void:
	var ros2 = get_node_or_null("/root/GodotROS2")
	if ros2 and ros2.has_method("initialize"):
		ros2.initialize("copernicus")
		Toast.show_toast(self, "ROS2 connecting…", Toast.Level.INFO)
	else:
		Toast.show_toast(self, "ROS2 bridge not available", Toast.Level.WARNING)


# ---------------------------------------------------------------- terminal

func _on_terminal_submit(text: String) -> void:
	_terminal_input.text = ""
	var line := text.strip_edges()
	if line.is_empty():
		return
	_echo("> " + line)
	var cmd := CommandRegistry.find(line)
	if cmd.is_empty():
		_echo("  unknown command: " + line)
		return
	CommandRegistry.run(cmd.get("id", ""))
	_echo("  ok: " + str(cmd.get("label", "")))


func _echo(msg: String) -> void:
	if not _terminal_output:
		return
	_terminal_output.text += msg + "\n"
	var sb := _terminal_output.get_v_scroll_bar()
	if sb:
		sb.value = sb.max_value


func _terminal_clear() -> void:
	if _terminal_output:
		_terminal_output.text = ""


func _terminal_help() -> void:
	if not _terminal_output:
		return
	var lines: Array = ["commands:"]
	for cmd in CommandRegistry.get_all():
		lines.append("  %s — %s" % [cmd.get("id", ""), cmd.get("label", "")])
	_terminal_output.text += "\n".join(lines) + "\n"
	var sb := _terminal_output.get_v_scroll_bar()
	if sb:
		sb.value = sb.max_value


# ---------------------------------------------------------------- context menu

func _on_context_menu_requested() -> void:
	var pos := DisplayServer.mouse_get_position()
	_context_menu.popup(Rect2i(Vector2i(pos), Vector2i.ZERO))


# ---------------------------------------------------------------- input / status

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			_open_palette()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_P:
			_open_palette()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and not event.shift_pressed and event.keycode == KEY_K:
			_open_palette()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _fps_label:
		_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	_update_status()


func _update_status() -> void:
	if not _status_wallet:
		return
	var rchain = get_node_or_null("/root/RChainService")
	if rchain and rchain.wallet and rchain.wallet.is_ready():
		var addr: String = rchain.wallet.get_rev_address()
		_status_wallet.text = "wallet: " + (addr.left(12) + "…" if addr.length() > 12 else addr)
	else:
		_status_wallet.text = "wallet: —"
	if _status_ros2:
		_status_ros2.text = "ros2: ✓" if _ros2_connected else "ros2: —"
	if _status_mode:
		var svc = get_node_or_null("/root/ScenarioService")
		var mode := "—"
		if svc and svc.active:
			mode = str(svc.active.mode)
		_status_mode.text = "mode: " + mode
