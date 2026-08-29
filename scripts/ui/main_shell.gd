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

enum MenuId {
	FILE_OPEN, FILE_RECENT, FILE_EXIT,
	VIEW_RESET, VIEW_WIREFRAME, VIEW_GRID, VIEW_DOMAIN, VIEW_TERMINAL,
	SENSOR_LIDAR, SENSOR_CAMERA, SENSOR_IMU,
	TOOL_IK, TOOL_PHYSICS, TOOL_NAV, TOOL_GPU, TOOL_OMNI, TOOL_INDUSTRIAL, TOOL_ROS2,
	TOOL_PHYSICS_DEMO, TOOL_TURTLE_DEMO,
	HELP_ABOUT,
}

const ACTIVITY_SPECS := [
	["viewer", "▦", "Viewer"],
	["robots", "◧", "Robots"],
	["marketplace", "◫", "Marketplace"],
	["wallet", "◈", "Wallet"],
	["coordination", "◍", "Coordination"],
	["raas", "▸", "RaaS"],
	["extensions", "◇", "Extensions"],
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
var _raas_demo: Control = null


func _ready() -> void:
	_load_persisted()
	_setup_ui()
	_setup_panels()
	_register_commands()
	_select_activity("viewer")


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
	bg.color = CopernicusTheme.BG_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_setup_menu_bar(root)

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


func _build_activity_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.x = 48
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = CopernicusTheme.BG_CARD
	sb.border_width_right = 1
	sb.border_color = CopernicusTheme.BORDER_DIM
	bar.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", CopernicusTheme.SPACE_XS)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_child(v)

	for spec in ACTIVITY_SPECS:
		var btn := Button.new()
		btn.text = spec[1]
		btn.tooltip_text = spec[2]
		btn.flat = true
		btn.custom_minimum_size = Vector2(40, 40)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_select_activity.bind(spec[0]))
		v.add_child(btn)
		_activity_buttons[spec[0]] = btn

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var settings := Button.new()
	settings.text = "≡"
	settings.tooltip_text = "Settings"
	settings.flat = true
	settings.custom_minimum_size = Vector2(40, 40)
	v.add_child(settings)

	return bar


func _build_side_bar() -> Control:
	_side_bar = PanelContainer.new()
	_side_bar.custom_minimum_size.x = 250
	_side_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_bar.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = CopernicusTheme.BG_CARD
	sb.border_width_right = 1
	sb.border_color = CopernicusTheme.BORDER_DIM
	_side_bar.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", CopernicusTheme.SPACE_S)
	_side_bar.add_child(v)

	_side_title = CopernicusTheme.make_heading("")
	v.add_child(_side_title)

	_side_content = Control.new()
	_side_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_side_content)

	return _side_bar


func _build_editor_group() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)

	_tab_bar = TabBar.new()
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_tab_bar.tab_close_pressed.connect(_on_tab_close)
	v.add_child(_tab_bar)

	_editor_content = Control.new()
	_editor_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_editor_content)

	return v


func _build_panel_host() -> Control:
	_panel_host = PanelContainer.new()
	_panel_host.custom_minimum_size.y = 140
	_panel_host.visible = false
	CopernicusTheme.style_panel(_panel_host)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_panel_host.add_child(v)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", CopernicusTheme.SPACE_S)
	v.add_child(bar)
	bar.add_child(CopernicusTheme.make_section("Terminal"))
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.pressed.connect(func() -> void: _panel_host.visible = false)
	bar.add_child(close)

	_terminal_output = TextEdit.new()
	_terminal_output.editable = false
	_terminal_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_terminal_output)

	_terminal_input = LineEdit.new()
	_terminal_input.placeholder_text = "> type a command"
	_terminal_input.text_submitted.connect(_on_terminal_submit)
	v.add_child(_terminal_input)

	return _panel_host


func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CopernicusTheme.BG_CARD
	sb.border_width_top = 1
	sb.border_color = CopernicusTheme.BORDER_DIM
	bar.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", CopernicusTheme.SPACE_M)
	bar.add_child(h)

	_status_left = HBoxContainer.new()
	_status_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_left.add_theme_constant_override("separation", CopernicusTheme.SPACE_M)
	h.add_child(_status_left)

	_status_wallet = CopernicusTheme.make_body("wallet: —")
	_status_left.add_child(_status_wallet)
	_status_left.add_child(CopernicusTheme.make_body("node: —"))
	_status_left.add_child(CopernicusTheme.make_body("ros2: —"))

	_status_right = HBoxContainer.new()
	h.add_child(_status_right)
	_fps_label = CopernicusTheme.make_body("0 fps")
	_status_right.add_child(_fps_label)

	return bar


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
	var robot_viewer = _workspace.get_robot_viewer()
	if robot_viewer:
		robot_viewer.context_menu_requested.connect(_on_context_menu_requested)

	var ai = AiAssistantPanel.new()
	_add_panel("ai", "AI Assistant", ai)
	if robot_viewer:
		ai.set_viewer(robot_viewer)

	var marketplace = MarketplacePanel.new()
	_add_panel("marketplace", "Marketplace", marketplace)

	_add_panel("wallet", "Wallet", WalletPanel.new())
	_add_panel("coordination", "Coordination", CoordinationPanel.new())

	var gallery = RobotGallery.new()
	gallery.set_workspace(_workspace)
	gallery.import_requested.connect(_open_file_dialog)
	gallery.robot_loaded.connect(func() -> void: _select_activity("viewer"))
	_add_panel("robots", "Robots", gallery)

	var raas = RaasLauncher.new()
	raas.demo_requested.connect(_on_raas_demo_requested)
	_add_panel("raas", "RaaS", raas)

	_add_panel("extensions", "Extensions", _build_extensions_panel())


func _add_panel(id: String, title: String, panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_content.add_child(panel)
	panel.visible = false
	_panels[id] = panel
	_tabs.append({"id": id, "title": title, "panel": panel})
	_tab_bar.add_tab(title)


func _build_extensions_panel() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", CopernicusTheme.SPACE_M)
	panel.add_child(v)
	v.add_child(CopernicusTheme.make_heading("Extensions"))
	v.add_child(CopernicusTheme.make_body("Modules contribute commands, views and status items. Registered via ModuleRegistry._static_init."))
	v.add_child(CopernicusTheme.make_separator())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for cat in ModuleRegistry.get_all_categories():
		list.add_child(CopernicusTheme.make_section(str(cat)))
		for mod in ModuleRegistry.get_available(cat):
			list.add_child(_extensions_row(mod))
	return panel


func _extensions_row(mod: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CopernicusTheme.SPACE_S)
	var name := Label.new()
	name.text = str(mod.get("name", mod.get("id", "?")))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", CopernicusTheme.TEXT_PRIMARY)
	row.add_child(name)
	var avail := Label.new()
	avail.text = "●" if mod.get("available", false) else "○"
	avail.add_theme_color_override("font_color", CopernicusTheme.SUCCESS if mod.get("available", false) else CopernicusTheme.TEXT_DISABLED)
	row.add_child(avail)
	return row


# ---------------------------------------------------------------- navigation

func _select_activity(id: String) -> void:
	if id != "raas" and _raas_demo and is_instance_valid(_raas_demo):
		_raas_demo.queue_free()
		_raas_demo = null
	_current_activity = id
	for key in _activity_buttons:
		CopernicusTheme.set_nav_active(_activity_buttons[key], key == id)
	_show_side_for(id)
	_focus_tab(id)


func _on_raas_demo_requested(scene_path: String) -> void:
	if _raas_demo and is_instance_valid(_raas_demo):
		_raas_demo.queue_free()
	var demo = load(scene_path).instantiate()
	demo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_content.add_child(demo)
	_raas_demo = demo
	if demo.has_signal("closed"):
		demo.closed.connect(func() -> void: _raas_demo = null)


func _show_side_for(id: String) -> void:
	match id:
		"viewer":
			_side_bar.visible = true
			_side_title.text = "Viewer"
			_clear_side()
			_side_content.add_child(CopernicusTheme.make_empty_state("Workspace", "Right-click the viewport for options."))
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
	if id in ["viewer", "marketplace", "wallet", "coordination", "robots", "raas", "extensions"]:
		return  # primary destinations stay open
	_tab_bar.remove_tab(index)
	_tabs.remove_at(index)


# ---------------------------------------------------------------- commands

func _register_commands() -> void:
	_reg("view.open", "Viewer: Open Workspace", "View", func() -> void: _select_activity("viewer"))
	_reg("robots.open", "Robots: Open Library", "View", func() -> void: _select_activity("robots"))
	_reg("marketplace.open", "Marketplace: Open", "View", func() -> void: _select_activity("marketplace"))
	_reg("wallet.open", "Wallet: Open", "View", func() -> void: _select_activity("wallet"))
	_reg("coordination.open", "Coordination: Open", "View", func() -> void: _select_activity("coordination"))
	_reg("raas.open", "RaaS: Open Demos", "View", func() -> void: _select_activity("raas"))
	_reg("extensions.open", "Extensions: List Modules", "View", func() -> void: _select_activity("extensions"))

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
			_open_demo("res://scenes/physics_demo.tscn")
		MenuId.TOOL_TURTLE_DEMO:
			_open_demo("res://scenes/turtle_demo.tscn")
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


func _open_demo(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


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
	_terminal_output.text += "> " + line + "\n"
	if not CommandRegistry.run(_line_to_id(line)):
		var matched := false
		for cmd in CommandRegistry.query(line):
			if str(cmd.get("label", "")).to_lower().begins_with(line.to_lower()):
				CommandRegistry.run(cmd.get("id", ""))
				matched = true
				break
		if not matched:
			_terminal_output.text += "  unknown command: " + line + "\n"


func _line_to_id(line: String) -> String:
	return line.strip_edges().replace(" ", "_").to_lower()


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
