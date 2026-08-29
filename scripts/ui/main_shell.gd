# main_shell.gd
# Desktop-style app shell: top menu bar + left sidebar + content host.

class_name MainShell
extends Control

const CompositeWorkspace = preload("res://scripts/composite_workspace.gd")
const AiAssistantPanel = preload("res://scripts/main.gd")
const MarketplacePanel = preload("res://scripts/marketplace/ui/marketplace_panel.gd")
const WalletPanel = preload("res://scripts/rchain/ui/wallet_panel.gd")
const CoordinationPanel = preload("res://scripts/rchain/ui/coordination_panel.gd")

enum MenuId {
	FILE_OPEN, FILE_EXIT,
	VIEW_RESET, VIEW_WIREFRAME, VIEW_GRID, VIEW_DOMAIN,
	SENSOR_LIDAR, SENSOR_CAMERA, SENSOR_IMU,
	TOOL_IK, TOOL_PHYSICS, TOOL_NAV, TOOL_GPU, TOOL_OMNI, TOOL_INDUSTRIAL, TOOL_ROS2,
	TOOL_PHYSICS_DEMO, TOOL_TURTLE_DEMO,
	HELP_ABOUT,
}

var _content_host: Control
var _nav_buttons: Dictionary = {}
var _panels: Dictionary = {}
var _workspace: CompositeWorkspace
var _file_dialog: FileDialog
var _context_menu: PopupMenu
var _view_menu: PopupMenu
var _sensors_menu: PopupMenu


func _ready() -> void:
	_setup_ui()
	_setup_panels()
	_select("viewer")


func _setup_ui() -> void:
	var bg = ColorRect.new()
	bg.color = CopernicusTheme.BG_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_setup_menu_bar(root)
	_setup_file_dialog()
	_setup_context_menu()

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	# ---- Sidebar ----
	var sidebar = PanelContainer.new()
	sidebar.custom_minimum_size.x = 200
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	CopernicusTheme.style_panel(sidebar)
	body.add_child(sidebar)

	var nav = VBoxContainer.new()
	nav.add_theme_constant_override("separation", CopernicusTheme.SPACE_XS)
	sidebar.add_child(nav)

	var brand = CopernicusTheme.make_heading("Copernicus")
	nav.add_child(brand)
	nav.add_child(CopernicusTheme.make_separator())

	for item in [
		["viewer", "Viewer"],
		["ai", "AI Assistant"],
		["marketplace", "Marketplace"],
		["wallet", "Wallet"],
		["coordination", "Coordination"],
	]:
		var btn = CopernicusTheme.make_nav_item(item[1], item[0])
		btn.pressed.connect(_on_nav_pressed.bind(item[0]))
		nav.add_child(btn)
		_nav_buttons[item[0]] = btn

	var raas_btn = CopernicusTheme.make_nav_item("RaaS Demos", "raas")
	raas_btn.pressed.connect(_open_raas)
	nav.add_child(raas_btn)

	# ---- Content host ----
	_content_host = Control.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content_host)


func _setup_menu_bar(root: VBoxContainer) -> void:
	var menu_bar = MenuBar.new()
	root.add_child(menu_bar)

	# File
	var file_menu = PopupMenu.new()
	file_menu.name = "File"
	file_menu.add_item("Open Robot…", MenuId.FILE_OPEN)
	file_menu.add_separator()
	file_menu.add_item("Exit", MenuId.FILE_EXIT)
	file_menu.id_pressed.connect(_on_menu_pressed)
	menu_bar.add_child(file_menu)

	# View
	_view_menu = PopupMenu.new()
	_view_menu.name = "View"
	menu_bar.add_child(_view_menu)

	# Sensors submenu (child of the View menu)
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
	_view_menu.id_pressed.connect(_on_menu_pressed)

	# Tools
	var tools_menu = PopupMenu.new()
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

	# Help
	var help_menu = PopupMenu.new()
	help_menu.name = "Help"
	help_menu.add_item("About", MenuId.HELP_ABOUT)
	help_menu.id_pressed.connect(_on_menu_pressed)
	menu_bar.add_child(help_menu)


func _setup_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.urdf ; URDF robot", "*.mjcf ; MJCF robot"])
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


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


func _setup_panels() -> void:
	_workspace = CompositeWorkspace.new()
	_add_panel("viewer", _workspace)
	var robot_viewer = _workspace.get_robot_viewer()
	if robot_viewer:
		robot_viewer.context_menu_requested.connect(_on_context_menu_requested)

	var ai = AiAssistantPanel.new()
	_add_panel("ai", ai)
	if robot_viewer:
		ai.set_viewer(robot_viewer)

	var marketplace = MarketplacePanel.new()
	_add_panel("marketplace", marketplace)
	marketplace.closed.connect(func() -> void: _select("viewer"))

	_add_panel("wallet", WalletPanel.new())
	_add_panel("coordination", CoordinationPanel.new())


func _add_panel(id: String, panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_host.add_child(panel)
	panel.visible = false
	_panels[id] = panel


func _select(id: String) -> void:
	for key in _panels:
		_panels[key].visible = (key == id)
	for key in _nav_buttons:
		CopernicusTheme.set_nav_active(_nav_buttons[key], key == id)


func _on_nav_pressed(id: String) -> void:
	_select(id)


func _open_raas() -> void:
	get_tree().change_scene_to_file("res://scenes/rchain/raas_launcher.tscn")


func _on_menu_pressed(id: int) -> void:
	match id:
		MenuId.FILE_OPEN:
			_file_dialog.popup_centered()
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
			get_tree().change_scene_to_file("res://scenes/physics_demo.tscn")
		MenuId.TOOL_TURTLE_DEMO:
			get_tree().change_scene_to_file("res://scenes/turtle_demo.tscn")
		MenuId.HELP_ABOUT:
			Toast.show_toast(self, "Copernicus — Robot Design Interface", Toast.Level.INFO)


func _toggle(menu: PopupMenu, id: int) -> bool:
	var idx = menu.get_item_index(id)
	menu.toggle_item_checked(idx)
	return menu.is_item_checked(idx)


func _on_file_selected(path: String) -> void:
	if path.ends_with(".urdf") or path.ends_with(".mjcf"):
		_workspace.load_urdf(path)
	else:
		Toast.show_toast(self, "Unsupported file type", Toast.Level.WARNING)


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


func _on_context_menu_requested() -> void:
	var pos = DisplayServer.mouse_get_position()
	_context_menu.popup(Rect2i(Vector2i(pos), Vector2i.ZERO))
