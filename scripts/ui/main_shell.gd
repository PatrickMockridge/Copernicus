# main_shell.gd
# IDE shell: robot editor (top) + docked terminal (bottom), activity rail +
# contextual side bar + status bar. Route-driven via NavigationModel — one source
# of truth for "which view is active".

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

var _workspace: CompositeWorkspace
var _navigation: NavigationModel
var _panels: Dictionary = {}          # id -> Control (cached editor panels)
var _factories: Dictionary = {}       # id -> Callable -> Control
var _sidebar_cache: Dictionary = {}   # id -> Control (cached side-bar content)
var _open_tabs: Array = []            # route ids, in tab order

var _activity_bar: UiActivityBar
var _side_bar: PanelContainer
var _side_title: Label
var _side_content: VBoxContainer
var _side_current: Control = null
var _tab_bar: TabBar
var _editor_host: Control
var _workbench: VSplitContainer
var _terminal: UiConsole
var _status_mode: UiStatusItem
var _status_wallet: UiStatusItem
var _status_node: UiStatusItem
var _status_ros2: UiStatusItem
var _fps_label: UiLabel
var _breadcrumb_label: UiLabel
var _back_btn: UiButton

var _file_dialog: FileDialog
var _recent_menu: PopupMenu
var _context_menu: PopupMenu
var _view_menu: PopupMenu
var _sensors_menu: PopupMenu
var _command_palette: CommandPalette

var _last_dir: String = ""
var _recent_robots: Array = []
var _overlay: Control = null
var _ros2_connected: bool = false


func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	_load_persisted()
	_navigation = NavigationModel.new()
	_navigation.route_changed.connect(_on_route_changed)
	_register_routes()
	_setup_ui()
	_register_commands()
	_setup_ros2()
	_navigate("editor")
	_check_node_async()


# ---------------------------------------------------------------- routes

func _register_routes() -> void:
	_reg_route("editor", "Editor", "▦", "design", 0, "view.open", true, _make_workspace, _make_objective_sidebar)
	_reg_route("wallet", "Wallet", "◈", "publish", 0, "wallet.open", true, _make_wallet)
	_reg_route("robots", "Robots", "◧", "design", 1, "robots.open", false, _make_gallery)
	_reg_route("marketplace", "Marketplace", "◫", "publish", 1, "marketplace.open", false, _make_marketplace)
	_reg_route("coordination", "Coordination", "◍", "publish", 2, "coordination.open", false, _make_coordination)
	_reg_route("vcs", "Version Control", "⇅", "utility", 0, "vcs.open", false, _make_vcs)
	_reg_route("raas", "RaaS", "▸", "operate", 0, "raas.open", false, _make_raas)
	_reg_route("ai", "AI Assistant", "◈", "utility", 1, "ai.open", false, _make_ai)
	_reg_route("extensions", "Extensions", "◇", "utility", 2, "extensions.open", false, _make_extensions)


func _reg_route(id: String, title: String, glyph: String, section: String, order: int, command_id: String, in_activity_bar: bool, factory: Callable, sidebar_factory: Callable = Callable()) -> void:
	_factories[id] = factory
	var r := Route.make(id, title, glyph, section, order, command_id, func() -> Control: return _ensure_panel(id), in_activity_bar)
	r.sidebar_factory = sidebar_factory
	_navigation.register(r)


func _make_workspace() -> Control:
	_workspace = CompositeWorkspace.new()
	# Connect before the node enters the tree so the demo robot's robot_loaded
	# (emitted during _ready) is not missed.
	_workspace.publish_requested.connect(_on_publish_requested)
	_workspace.robot_loaded.connect(_on_robot_loaded_for_scenario)
	return _workspace


func _make_wallet() -> Control:
	return WalletPanel.new()


func _make_gallery() -> Control:
	var gallery = RobotGallery.new()
	if _workspace:
		gallery.set_workspace(_workspace)
	gallery.import_requested.connect(_open_file_dialog)
	gallery.robot_loaded.connect(func() -> void: _navigate("editor"))
	return gallery


func _make_marketplace() -> Control:
	var marketplace = MarketplacePanel.new()
	marketplace.closed.connect(func() -> void: _navigate("editor"))
	return marketplace


func _make_coordination() -> Control:
	return CoordinationPanel.new()


func _make_vcs() -> Control:
	return VcsPanel.new()


func _make_raas() -> Control:
	var raas = RaasLauncher.new()
	raas.demo_requested.connect(_on_raas_demo_requested)
	return raas


func _make_ai() -> Control:
	var ai = AiAssistantPanel.new()
	if _workspace:
		ai.set_viewer(_workspace.get_robot_viewer())
	return ai


func _make_extensions() -> Control:
	return _build_extensions_panel()


func _make_objective_sidebar() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.space("s"))
	v.add_child(UiBrief.new().configure())
	return v


func _ensure_panel(id: String) -> Control:
	if _panels.has(id) and is_instance_valid(_panels[id]):
		return _panels[id]
	var factory: Callable = _factories.get(id)
	if not factory.is_valid():
		push_error("MainShell: no factory for route '%s'" % id)
		return null
	var panel: Control = factory.call()
	if panel == null:
		return null
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_host.add_child(panel)
	panel.visible = false
	_panels[id] = panel
	if id == "editor":
		_wire_viewer()
	return panel


func _wire_viewer() -> void:
	var viewer = _workspace.get_robot_viewer()
	if viewer and not viewer.context_menu_requested.is_connected(_on_context_menu_requested):
		viewer.context_menu_requested.connect(_on_context_menu_requested)


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

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	body.add_child(_build_activity_bar())
	body.add_child(_build_side_bar())
	body.add_child(_build_center())

	root.add_child(_build_status_bar())

	_setup_file_dialog()
	_setup_context_menu()


func _build_activity_bar() -> Control:
	_activity_bar = UiActivityBar.new()
	_activity_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var entries: Array = []
	for r in _navigation.ordered_routes():
		if r.in_activity_bar:
			entries.append({"id": r.id, "glyph": r.glyph, "title": r.title})
	_activity_bar.setup(entries)
	_activity_bar.activity_selected.connect(_navigate)
	return _activity_bar


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
	v.add_child(tb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", UiTheme.space("m"))
	margin.add_theme_constant_override("margin_right", UiTheme.space("m"))
	margin.add_theme_constant_override("margin_top", UiTheme.space("m"))
	margin.add_theme_constant_override("margin_bottom", UiTheme.space("m"))
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(margin)

	_side_content = VBoxContainer.new()
	_side_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_side_content)

	return _side_bar


func _build_center() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)

	_tab_bar = TabBar.new()
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	_tab_bar.tab_changed.connect(_on_tab_changed)
	center.add_child(_tab_bar)

	_workbench = VSplitContainer.new()
	_workbench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workbench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var h := get_viewport_rect().size.y
	_workbench.split_offset = int(h * 0.68) if h > 0 else 480
	center.add_child(_workbench)

	_editor_host = Control.new()
	_editor_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workbench.add_child(_editor_host)

	_terminal = UiConsole.new().configure("Terminal")
	_terminal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_terminal.command_submitted.connect(_on_terminal_submit)
	_workbench.add_child(_terminal)

	return center


func _build_status_bar() -> Control:
	var bar := UiStatusBar.new().setup()
	var left := bar.left()
	var right := bar.right()

	_back_btn = UiButton.new().setup("◀", UiButton.Variant.GHOST)
	_back_btn.tooltip_text = "Back"
	_back_btn.pressed.connect(_on_back)
	left.add_child(_back_btn)

	_breadcrumb_label = UiLabel.new().setup("", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED)
	left.add_child(_breadcrumb_label)

	_status_mode = UiStatusItem.new().setup("mode")
	left.add_child(_status_mode)
	_status_wallet = UiStatusItem.new().setup("wallet")
	left.add_child(_status_wallet)
	_status_node = UiStatusItem.new().setup("node")
	left.add_child(_status_node)
	_status_ros2 = UiStatusItem.new().setup("ros2")
	left.add_child(_status_ros2)

	var term_btn := UiButton.new().setup("Terminal", UiButton.Variant.GHOST)
	term_btn.pressed.connect(_toggle_terminal)
	right.add_child(term_btn)
	_fps_label = UiLabel.new().setup("0 fps", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED)
	right.add_child(_fps_label)

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


# ---------------------------------------------------------------- navigation

func _navigate(id: String) -> void:
	_navigation.navigate(id)


func _on_back() -> void:
	_navigation.back()


func _on_route_changed(_from: String, to: String) -> void:
	_close_overlay()
	var route := _navigation.get_route(to)
	if route == null:
		return
	_ensure_panel(to)
	if not _open_tabs.has(to):
		_open_tabs.append(to)
	_sync_tabs()
	_show_panel(to)
	_activity_bar.set_active(to)
	_update_side_bar(route)
	_update_breadcrumb()
	_update_status()


func _show_panel(id: String) -> void:
	for key in _panels:
		_panels[key].visible = (key == id)


func _sync_tabs() -> void:
	_tab_bar.set_block_signals(true)
	_tab_bar.clear_tabs()
	for id in _open_tabs:
		var route := _navigation.get_route(id)
		_tab_bar.add_tab(route.title if route else id)
	var idx := _open_tabs.find(_navigation.current_id)
	if idx >= 0:
		_tab_bar.current_tab = idx
	_tab_bar.set_block_signals(false)


func _on_tab_changed(index: int) -> void:
	if index < 0 or index >= _open_tabs.size():
		return
	_navigate(_open_tabs[index])


func _update_side_bar(route: Route) -> void:
	if _side_current and _side_current.get_parent() == _side_content:
		_side_content.remove_child(_side_current)
	_side_current = null
	if not route.sidebar_factory.is_valid():
		_side_bar.visible = false
		return
	if not _sidebar_cache.has(route.id):
		_sidebar_cache[route.id] = route.sidebar_factory.call()
	_side_current = _sidebar_cache[route.id]
	_side_content.add_child(_side_current)
	_side_bar.visible = true
	_side_title.text = route.title


func _update_breadcrumb() -> void:
	var parts: Array = []
	for r in _navigation.breadcrumb():
		parts.append(r.title)
	_breadcrumb_label.text = " ▸ ".join(parts)


# ---------------------------------------------------------------- panels

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
	var name := UiLabel.new().setup(str(mod.get("name", mod.get("id", "?"))), UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var avail := UiLabel.new().setup("●" if mod.get("available", false) else "○", UiLabel.Kind.SMALL, UiLabel.Tone.SUCCESS if mod.get("available", false) else UiLabel.Tone.FAINT)
	row.add_child(avail)
	return row


# ---------------------------------------------------------------- commands

func _register_commands() -> void:
	_reg("view.open", "Editor: Open", "View", func() -> void: _navigate("editor"))
	_reg("wallet.open", "Wallet: Open", "View", func() -> void: _navigate("wallet"))
	_reg("robots.open", "Robots: Open Library", "View", func() -> void: _navigate("robots"))
	_reg("marketplace.open", "Marketplace: Open", "View", func() -> void: _navigate("marketplace"))
	_reg("coordination.open", "Coordination: Open", "View", func() -> void: _navigate("coordination"))
	_reg("vcs.open", "Version Control: Open", "View", func() -> void: _navigate("vcs"))
	_reg("raas.open", "RaaS: Open Demos", "View", func() -> void: _navigate("raas"))
	_reg("ai.open", "AI Assistant: Open", "View", func() -> void: _navigate("ai"))
	_reg("extensions.open", "Extensions: List Modules", "View", func() -> void: _navigate("extensions"))

	_reg("robot.open", "Open Robot…", "File", func() -> void: _open_file_dialog())
	_reg("view.reset", "View: Reset", "View", func() -> void: var v := _viewer(); if v: v.reset_view())
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


func _viewer() -> RobotViewerController:
	if _workspace:
		return _workspace.get_robot_viewer()
	return null


# ---------------------------------------------------------------- menu dispatch

func _on_menu_pressed(id: int) -> void:
	match id:
		MenuId.FILE_OPEN:
			_open_file_dialog()
		MenuId.FILE_EXIT:
			get_tree().quit()
		MenuId.VIEW_RESET:
			var v := _viewer()
			if v: v.reset_view()
		MenuId.VIEW_WIREFRAME:
			var on := _toggle(_view_menu, MenuId.VIEW_WIREFRAME)
			var vw := _viewer()
			if vw: vw.set_show_debug(on)
		MenuId.VIEW_GRID:
			var on := _toggle(_view_menu, MenuId.VIEW_GRID)
			var vg := _viewer()
			if vg: vg.set_grid_visible(on)
		MenuId.VIEW_DOMAIN:
			if _workspace:
				_workspace.set_domain_randomization(_toggle(_view_menu, MenuId.VIEW_DOMAIN))
		MenuId.VIEW_TERMINAL:
			_toggle_terminal()
		MenuId.SENSOR_LIDAR:
			_set_lidar(_toggle(_sensors_menu, MenuId.SENSOR_LIDAR))
		MenuId.SENSOR_CAMERA:
			_set_camera(_toggle(_sensors_menu, MenuId.SENSOR_CAMERA))
		MenuId.SENSOR_IMU:
			_set_imu(_toggle(_sensors_menu, MenuId.SENSOR_IMU))
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
	var v := _viewer()
	if v:
		v.set_show_debug(not v.is_show_debug())

func _toggle_grid() -> void:
	var v := _viewer()
	if v:
		v.set_grid_visible(not v.is_grid_visible())

func _toggle_domain() -> void:
	if _workspace:
		_workspace.set_domain_randomization(not _workspace.is_domain_randomization_enabled())

func _toggle_lidar() -> void:
	if _workspace:
		_set_lidar(not _workspace.is_lidar_visible())

func _toggle_camera() -> void:
	if _workspace:
		_set_camera(not _workspace.is_camera_visible())

func _toggle_imu() -> void:
	if _workspace:
		_set_imu(not _workspace.is_imu_visible())

func _set_lidar(visible: bool) -> void:
	if not _workspace:
		return
	_workspace.set_lidar_visible(visible)
	_mark_scenario("lidar_active", visible)

func _set_camera(visible: bool) -> void:
	if not _workspace:
		return
	_workspace.set_camera_visible(visible)
	_mark_scenario("camera_active", visible)

func _set_imu(visible: bool) -> void:
	if not _workspace:
		return
	_workspace.set_imu_visible(visible)
	_mark_scenario("imu_active", visible)

func _toggle_terminal() -> void:
	_terminal.visible = not _terminal.visible
	_workbench.dragger_visibility = SplitContainer.DRAGGER_VISIBLE if _terminal.visible else SplitContainer.DRAGGER_HIDDEN
	if _terminal.visible:
		_terminal.focus_input()


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
		_navigate("editor")
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


func _open_file_dialog() -> void:
	_file_dialog.current_dir = _default_open_dir()
	_file_dialog.popup_centered()


func _open_demo(scene_path: String, title: String = "") -> void:
	if title.is_empty():
		title = scene_path.get_file().get_basename().capitalize().replace("_", " ")
	_close_overlay()
	var host = DemoHost.new()
	host.setup(scene_path, title)
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_host.add_child(host)
	_overlay = host
	host.closed.connect(func() -> void: _overlay = null)


func _open_selector(scene_path: String) -> void:
	var res := load(scene_path)
	if res == null:
		Toast.show_toast(self, "Missing scene: " + scene_path, Toast.Level.ERROR)
		return
	add_child(res.instantiate())


func _connect_ros2() -> void:
	var ros2 = get_node_or_null("/root/GodotROS2")
	if ros2 and ros2.has_method("initialize"):
		ros2.initialize("copernicus")
		Toast.show_toast(self, "ROS2 connecting…", Toast.Level.INFO)
	else:
		Toast.show_toast(self, "ROS2 bridge not available", Toast.Level.WARNING)


# ---------------------------------------------------------------- overlays

func _close_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null


func _on_publish_requested(robot_name: String) -> void:
	_close_overlay()
	var panel = PublishPanel.show_for_robot(robot_name)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_host.add_child(panel)
	_overlay = panel
	panel.tree_exited.connect(func() -> void: _overlay = null)


func _on_raas_demo_requested(scene_path: String) -> void:
	_close_overlay()
	var res := load(scene_path)
	if res == null:
		Toast.show_toast(self, "Missing scene: " + scene_path, Toast.Level.ERROR)
		return
	var demo = res.instantiate()
	demo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_host.add_child(demo)
	_overlay = demo
	if demo.has_signal("closed"):
		demo.closed.connect(func() -> void: _overlay = null)


# ---------------------------------------------------------------- terminal

func _on_terminal_submit(text: String) -> void:
	var line := text.strip_edges()
	if line.is_empty():
		return
	_terminal.echo("> " + line)
	var cmd := CommandRegistry.find(line)
	if cmd.is_empty():
		_terminal.echo("  unknown command: " + line)
		return
	CommandRegistry.run(cmd.get("id", ""))
	_terminal.echo("  ok: " + str(cmd.get("label", "")))


func _terminal_clear() -> void:
	if _terminal:
		_terminal.clear()


func _terminal_help() -> void:
	if not _terminal:
		return
	var lines: Array = ["commands:"]
	for cmd in CommandRegistry.get_all():
		lines.append("  %s — %s" % [cmd.get("id", ""), cmd.get("label", "")])
	_terminal.echo("\n".join(lines))


# ---------------------------------------------------------------- context menu / input / status

func _on_context_menu_requested() -> void:
	var pos := DisplayServer.mouse_get_position()
	_context_menu.popup(Rect2i(Vector2i(pos), Vector2i.ZERO))


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


func _open_palette() -> void:
	if _command_palette and is_instance_valid(_command_palette):
		return
	_command_palette = CommandPalette.new()
	add_child(_command_palette)


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
		_status_wallet.set_state(UiStatusItem.State.OK, addr.left(12) + "…" if addr.length() > 12 else addr)
	else:
		_status_wallet.set_state(UiStatusItem.State.OFF, "—")
	if _status_ros2:
		_status_ros2.set_state(UiStatusItem.State.OK if _ros2_connected else UiStatusItem.State.OFF, "✓" if _ros2_connected else "—")
	if _status_mode:
		var svc = get_node_or_null("/root/ScenarioService")
		var mode := "—"
		if svc and svc.active:
			mode = str(svc.active.mode)
		_status_mode.set_state(UiStatusItem.State.OK, mode)


# ---------------------------------------------------------------- ros2 / node / scenario

func _setup_ros2() -> void:
	var ros2 = get_node_or_null("/root/GodotROS2")
	if ros2 and ros2.has_signal("initialization_completed"):
		ros2.initialization_completed.connect(func(success: bool) -> void:
			_ros2_connected = success
			_mark_scenario("ros2_connected", success)
		)


func _check_node_async() -> void:
	var rchain = get_node_or_null("/root/RChainService")
	if rchain and rchain.node and rchain.has_method("run_async"):
		rchain.run_async(func() -> Variant: return rchain.node.get_status(), _on_node_checked)


func _on_node_checked(r) -> void:
	if not _status_node:
		return
	if r != null and r.is_ok():
		_status_node.set_state(UiStatusItem.State.OK, "✓")
	else:
		_status_node.set_state(UiStatusItem.State.OFF, "offline")


func _mark_scenario(key: String, value: Variant) -> void:
	var svc = get_node_or_null("/root/ScenarioService")
	if svc:
		svc.context[key] = value
		svc.reevaluate()


func _on_robot_loaded_for_scenario(_node: Node3D) -> void:
	_mark_scenario("robot_loaded", true)


# ---------------------------------------------------------------- persistence

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


func _default_open_dir() -> String:
	if not _last_dir.is_empty() and DirAccess.dir_exists_absolute(_last_dir):
		return _last_dir
	var home := OS.get_environment("HOME")
	if not home.is_empty() and DirAccess.dir_exists_absolute(home):
		return home
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
