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
const ShortcutManager = preload("res://scripts/viewport/shortcut_manager.gd")

enum MenuId {
	FILE_OPEN, FILE_RECENT, FILE_MANUAL, FILE_EXIT,
	VIEW_RESET, VIEW_WIREFRAME, VIEW_GRID, VIEW_DOMAIN, VIEW_TERMINAL,
	SENSOR_LIDAR, SENSOR_CAMERA, SENSOR_IMU,
	TOOL_IK, TOOL_PHYSICS, TOOL_NAV, TOOL_GPU, TOOL_OMNI, TOOL_INDUSTRIAL, TOOL_ROS2,
	TOOL_PHYSICS_DEMO, TOOL_TURTLE_DEMO,
	HELP_ABOUT,
}

var _workspace: CompositeWorkspace
var _navigation: NavigationModel
var _cli: Cli
var _panels: Dictionary = {}          # id -> Control (cached editor panels)
var _factories: Dictionary = {}       # id -> Callable -> Control
var _sidebar_cache: Dictionary = {}   # id -> Control (cached side-bar content)
var _open_tabs: Array = []            # route ids, in tab order
var _plugins: Array = []              # disable-able views
var _plugin_enabled: Dictionary = {}  # id -> bool

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
var _view_menu: PopupMenu
var _sensors_menu: PopupMenu
var _command_palette: CommandPalette
var _shortcuts: ShortcutManager

var _last_dir: String = ""
var _recent_robots: Array = []
var _overlay: Control = null
var _ros2_connected: bool = false


func _ready() -> void:
	get_window().min_size = Vector2i(960, 600)
	_load_persisted()
	_navigation = NavigationModel.new()
	_navigation.route_changed.connect(_on_route_changed)
	_build_plugins()
	_load_plugin_state()
	_register_routes()
	_setup_ui()
	_shortcuts = ShortcutManager.new()
	_shortcuts.load_from("user://shortcuts.json")
	_cli = Cli.new(CommandRegistry)
	_register_commands()
	_setup_ros2()
	_wire_scenario_service()
	_navigate("editor")
	_check_node_async()
	_terminal.echo("    **** COPENICUS TERMINAL V1 ****")
	_terminal.echo("READY.")


# ---------------------------------------------------------------- routes

func _register_routes() -> void:
	_reg_route("editor", "Editor", "▦", "design", 0, "view.open", true, _make_workspace, _make_objective_sidebar)
	_reg_route("wallet", "Wallet", "◈", "publish", 0, "wallet.open", true, _make_wallet)
	for p in _plugins:
		if _is_plugin_enabled(p["id"]):
			_reg_route(p["id"], p["title"], p["glyph"], p["section"], p["order"], p["command"], false, p["factory"])
	_reg_route("plugins", "Plugins", "◇", "utility", 3, "plugins.open", false, _make_plugins)
	_reg_route("manual", "Manual", "▤", "utility", 4, "manual.open", false, _make_manual)


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
	_workspace.wireframe_changed.connect(_on_wireframe_changed)
	_workspace.grid_changed.connect(_on_grid_changed)
	_workspace.viewport_action.connect(_on_viewport_action)
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


func _build_plugins() -> void:
	_plugins = [
		{"id": "robots", "title": "Robots", "glyph": "◧", "section": "design", "order": 1, "command": "robots.open", "command_label": "Robots: Open Library", "factory": _make_gallery, "description": "Browse and load robot models from the library."},
		{"id": "marketplace", "title": "Marketplace", "glyph": "◫", "section": "publish", "order": 1, "command": "marketplace.open", "command_label": "Marketplace: Open", "factory": _make_marketplace, "description": "Buy, sell, and list robot designs."},
		{"id": "coordination", "title": "Coordination", "glyph": "◍", "section": "publish", "order": 2, "command": "coordination.open", "command_label": "Coordination: Open", "factory": _make_coordination, "description": "Register robots and coordinate work on-chain."},
		{"id": "vcs", "title": "Version Control", "glyph": "⇅", "section": "utility", "order": 0, "command": "vcs.open", "command_label": "Version Control: Open", "factory": _make_vcs, "description": "Git/GitHub/GitLab versioning for designs."},
		{"id": "raas", "title": "RaaS", "glyph": "▸", "section": "operate", "order": 0, "command": "raas.open", "command_label": "RaaS: Open Demos", "factory": _make_raas, "description": "Robotics-as-a-Service demos."},
		{"id": "ai", "title": "AI Assistant", "glyph": "◈", "section": "utility", "order": 1, "command": "ai.open", "command_label": "AI Assistant: Open", "factory": _make_ai, "description": "AI code generation and debugging."},
	]


func _load_plugin_state() -> void:
	for p in _plugins:
		_plugin_enabled[p["id"]] = true
	var f := FileAccess.open("user://plugins.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for id in _plugin_enabled:
				if parsed.has(id):
					_plugin_enabled[id] = bool(parsed[id])


func _save_plugin_state() -> void:
	var f := FileAccess.open("user://plugins.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_plugin_enabled))


func _is_plugin_enabled(id: String) -> bool:
	return _plugin_enabled.get(id, true)


func _plugin_by_id(id: String) -> Dictionary:
	for p in _plugins:
		if p["id"] == id:
			return p
	return {}


func _set_plugin_enabled(id: String, enabled: bool) -> void:
	_plugin_enabled[id] = enabled
	_save_plugin_state()
	if enabled:
		_register_plugin(id)
	else:
		_unregister_plugin(id)


func _register_plugin(id: String) -> void:
	var p := _plugin_by_id(id)
	if p.is_empty():
		return
	_reg_route(id, p["title"], p["glyph"], p["section"], p["order"], p["command"], false, p["factory"])


func _unregister_plugin(id: String) -> void:
	var was_current := _navigation.current_id == id
	_navigation.unregister(id)
	_open_tabs.erase(id)
	if was_current:
		_navigate("editor")
	else:
		_sync_tabs()


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
	if viewer and not viewer.target_reached.is_connected(_on_target_reached):
		viewer.target_reached.connect(_on_target_reached)
	if viewer and not viewer.joints_zeroed.is_connected(_on_joints_zeroed):
		viewer.joints_zeroed.connect(_on_joints_zeroed)


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
	center.add_child(_workbench)

	_editor_host = Control.new()
	_editor_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_host.size_flags_stretch_ratio = 2.0
	_workbench.add_child(_editor_host)

	_terminal = UiConsole.new().configure("Terminal")
	_terminal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_terminal.size_flags_stretch_ratio = 1.0
	_terminal.custom_minimum_size.y = 120
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
	file_menu.add_item("Manual…", MenuId.FILE_MANUAL)
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

func _make_plugins() -> Control:
	var win := UiPanel.new().setup("Plugins")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v: VBoxContainer = win.body()
	v.add_child(UiLabel.new().setup("Enable or disable optional plugins. Changes take effect immediately.", UiLabel.Kind.BODY, UiLabel.Tone.MUTED))
	v.add_child(UiSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for p in _plugins:
		list.add_child(_plugin_row(p))
	list.add_child(UiSeparator.new())
	list.add_child(UiSection.new().setup("Backends"))
	for cat in ModuleRegistry.get_all_categories():
		list.add_child(UiSection.new().setup(str(cat)))
		for mod in ModuleRegistry.get_available(cat):
			list.add_child(_extensions_row(mod))
	return win


func _make_manual() -> Control:
	return UiManual.new().configure()


func _plugin_row(p: Dictionary) -> Control:
	var card := UiPanel.new().setup("")
	var v: VBoxContainer = card.body()
	var top := HBoxContainer.new()
	v.add_child(top)
	var toggle := CheckBox.new()
	toggle.button_pressed = _is_plugin_enabled(p["id"])
	toggle.toggled.connect(func(on: bool) -> void: _set_plugin_enabled(p["id"], on))
	top.add_child(toggle)
	var title := UiLabel.new().setup(str(p["title"]), UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var desc := UiLabel.new().setup(str(p.get("description", "")), UiLabel.Kind.SMALL, UiLabel.Tone.MUTED)
	v.add_child(desc)
	return card


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
	_cmd("open", "<view>", "Open a view (editor, wallet, marketplace, vcs, coordination, raas, robots, ai, plugins)", "view", _cmd_open)
	_cmd("load", "<id|path>", "Load a library robot (turtlebot, arm6, …) or a .urdf/.mjcf path", "robot", _cmd_load)
	_cmd("back", "", "Navigate back", "nav", _cmd_back)
	_cmd("mode", "", "Show the active scenario and mode", "nav", _cmd_mode)
	_cmd("wireframe", "[on|off]", "Set or toggle wireframe", "view", _cmd_wireframe)
	_cmd("grid", "[on|off]", "Set or toggle grid", "view", _cmd_grid)
	_cmd("sensors", "<lidar|camera|imu> [on|off]", "Set or toggle a sensor", "view", _cmd_sensors)
	_cmd("demo", "<physics|turtle>", "Open a demo", "demo", _cmd_demo)
	_cmd("tool", "<ik|physics|nav|gpu|omni|industrial>", "Open a tool selector", "tool", _cmd_tool)
	_cmd("ros2", "", "Connect the ROS2 bridge", "tool", _cmd_ros2)
	_cmd("plugins", "", "Open the plugin manager", "meta", _cmd_plugins)
	_cmd("list", "", "List the command catalog", "meta", _cmd_list)
	_cmd("commands", "", "Alias for list", "meta", _cmd_list)
	_cmd("help", "[command]", "Show help for a command", "meta", _cmd_help)
	_cmd("clear", "", "Clear the terminal", "meta", _cmd_clear)

	# Plugin-contributed commands (modules registered via ModuleRegistry).
	for cmd in ModuleRegistry.get_contributed_commands():
		if cmd is Dictionary and cmd.has("name") and cmd.has("handler"):
			CommandRegistry.register(cmd)


func _cmd(name: String, syntax: String, description: String, category: String, handler: Callable) -> void:
	CommandRegistry.register({"name": name, "syntax": syntax, "description": description, "category": category, "handler": handler})


# ---------------------------------------------------------------- CLI handlers

func _on_off(v: Variant) -> Variant:
	match str(v).to_lower():
		"on", "true", "1": return true
		"off", "false", "0": return false
		_: return null


func _cmd_open(args: Array, out: Callable) -> bool:
	if args.is_empty():
		out.call("?SYNTAX ERROR")
		return false
	var view: String = str(args[0]).to_lower()
	if _navigation.get_route(view) == null:
		out.call("?BAD ARGUMENT: " + view)
		return false
	_navigate(view)
	return true


func _cmd_load(args: Array, out: Callable) -> bool:
	if args.is_empty():
		out.call("?SYNTAX ERROR")
		return false
	var target: String = str(args[0])
	if target.to_lower().ends_with(".urdf") or target.to_lower().ends_with(".mjcf"):
		if not FileAccess.file_exists(target):
			out.call("?FILE NOT FOUND")
			return false
		_ensure_panel("editor")
		if target.to_lower().ends_with(".mjcf"):
			_workspace.load_mjcf(target)
		else:
			_workspace.load_urdf(target)
		out.call("loaded " + target)
		return true
	var lib = get_node_or_null("/root/RobotLibrary")
	if lib and lib.has_method("build") and lib.build(target.to_lower()) != null:
		_load_library_robot(target.to_lower())
		out.call("loaded " + target)
		return true
	out.call("?BAD ARGUMENT: " + target)
	return false


func _cmd_back(_args: Array, _out: Callable) -> bool:
	return _navigation.back()


func _cmd_mode(_args: Array, out: Callable) -> bool:
	var svc = get_node_or_null("/root/ScenarioService")
	if svc and svc.active:
		out.call("%s — %s" % [svc.active.title, svc.active.mode])
	else:
		out.call("no active scenario")
	return true


func _cmd_wireframe(args: Array, out: Callable) -> bool:
	if not _workspace:
		return false
	var new_val: bool
	if args.is_empty():
		new_val = not _workspace.is_wireframe()
	else:
		var parsed = _on_off(args[0])
		if parsed == null:
			out.call("?BAD ARGUMENT: " + str(args[0]))
			return false
		new_val = parsed
	_workspace.set_wireframe(new_val)
	out.call("wireframe " + ("on" if new_val else "off"))
	return true


func _cmd_grid(args: Array, out: Callable) -> bool:
	if not _workspace:
		return false
	var new_val: bool
	if args.is_empty():
		new_val = not _workspace.is_grid()
	else:
		var parsed = _on_off(args[0])
		if parsed == null:
			out.call("?BAD ARGUMENT: " + str(args[0]))
			return false
		new_val = parsed
	_workspace.set_grid(new_val)
	out.call("grid " + ("on" if new_val else "off"))
	return true


func _cmd_sensors(args: Array, out: Callable) -> bool:
	if args.is_empty():
		out.call("?SYNTAX ERROR")
		return false
	var sensor: String = str(args[0]).to_lower()
	var set_to: Variant = null
	if args.size() > 1:
		set_to = _on_off(args[1])
		if set_to == null:
			out.call("?BAD ARGUMENT: " + str(args[1]))
			return false
	var new_val: bool = false
	match sensor:
		"lidar":
			new_val = (not _workspace.is_lidar_visible()) if set_to == null else bool(set_to)
			_set_lidar(new_val)
		"camera":
			new_val = (not _workspace.is_camera_visible()) if set_to == null else bool(set_to)
			_set_camera(new_val)
		"imu":
			new_val = (not _workspace.is_imu_visible()) if set_to == null else bool(set_to)
			_set_imu(new_val)
		_:
			out.call("?BAD ARGUMENT: " + sensor)
			return false
	out.call("sensors " + sensor + (" on" if new_val else " off"))
	return true


func _cmd_demo(args: Array, out: Callable) -> bool:
	if args.is_empty():
		out.call("?SYNTAX ERROR")
		return false
	match str(args[0]).to_lower():
		"physics":
			_open_demo("res://scenes/physics_demo.tscn", "Physics Demo")
		"turtle":
			_open_demo("res://scenes/turtle_demo.tscn", "Turtle Demo")
		_:
			out.call("?BAD ARGUMENT: " + str(args[0]))
			return false
	return true


func _cmd_tool(args: Array, out: Callable) -> bool:
	if args.is_empty():
		out.call("?SYNTAX ERROR")
		return false
	var scene := ""
	match str(args[0]).to_lower():
		"ik": scene = "res://scenes/ik_selector.tscn"
		"physics": scene = "res://scenes/physics_selector.tscn"
		"nav": scene = "res://scenes/nav_selector.tscn"
		"gpu": scene = "res://scenes/gpu/gpu_backend_selector.tscn"
		"omni": scene = "res://scenes/omni_selector.tscn"
		"industrial": scene = "res://scenes/industrial_selector.tscn"
		_:
			out.call("?BAD ARGUMENT: " + str(args[0]))
			return false
	_open_selector(scene)
	return true


func _cmd_ros2(_args: Array, out: Callable) -> bool:
	_connect_ros2()
	out.call("ros2 connecting")
	return true


func _cmd_plugins(_args: Array, _out: Callable) -> bool:
	_navigate("plugins")
	return true


func _cmd_list(_args: Array, out: Callable) -> bool:
	for line in _cli.catalog_lines():
		out.call(str(line))
	return true


func _cmd_help(args: Array, out: Callable) -> bool:
	var name := "" if args.is_empty() else str(args[0])
	for line in _cli.help_lines(name):
		out.call(str(line))
	return true


func _cmd_clear(_args: Array, _out: Callable) -> bool:
	if _terminal:
		_terminal.clear()
	return true


func _viewer() -> RobotViewerController:
	if _workspace:
		return _workspace.get_robot_viewer()
	return null


# ---------------------------------------------------------------- menu dispatch

func _on_menu_pressed(id: int) -> void:
	match id:
		MenuId.FILE_OPEN:
			_open_file_dialog()
		MenuId.FILE_MANUAL:
			_navigate("manual")
		MenuId.FILE_EXIT:
			get_tree().quit()
		MenuId.VIEW_RESET:
			var v := _viewer()
			if v: v.reset_view()
		MenuId.VIEW_WIREFRAME:
			if _workspace:
				_workspace.set_wireframe(not _workspace.is_wireframe())
		MenuId.VIEW_GRID:
			if _workspace:
				_workspace.set_grid(not _workspace.is_grid())
		MenuId.VIEW_DOMAIN:
			if _workspace:
				_set_domain(not _workspace.is_domain_randomization_enabled())
		MenuId.VIEW_TERMINAL:
			_toggle_terminal()
		MenuId.SENSOR_LIDAR:
			if _workspace:
				_set_lidar(not _workspace.is_lidar_visible())
		MenuId.SENSOR_CAMERA:
			if _workspace:
				_set_camera(not _workspace.is_camera_visible())
		MenuId.SENSOR_IMU:
			if _workspace:
				_set_imu(not _workspace.is_imu_visible())
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


func _toggle_wireframe() -> void:
	if _workspace:
		_workspace.set_wireframe(not _workspace.is_wireframe())

func _toggle_grid() -> void:
	if _workspace:
		_workspace.set_grid(not _workspace.is_grid())

func _toggle_domain() -> void:
	if _workspace:
		_set_domain(not _workspace.is_domain_randomization_enabled())

func _toggle_lidar() -> void:
	if _workspace:
		_set_lidar(not _workspace.is_lidar_visible())

func _toggle_camera() -> void:
	if _workspace:
		_set_camera(not _workspace.is_camera_visible())

func _toggle_imu() -> void:
	if _workspace:
		_set_imu(not _workspace.is_imu_visible())


## Shell-level actions requested by the viewport context menu / shortcuts.
func _on_viewport_action(id: String) -> void:
	match id:
		"load_robot":
			_open_file_dialog()
		"wireframe":
			_toggle_wireframe()
		"grid":
			_toggle_grid()
		"lidar":
			_toggle_lidar()
		"camera":
			_toggle_camera()
		"imu":
			_toggle_imu()
		"domain":
			_toggle_domain()

func _set_domain(enabled: bool) -> void:
	if not _workspace:
		return
	_workspace.set_domain_randomization(enabled)
	_set_menu_checked(_view_menu, MenuId.VIEW_DOMAIN, enabled)
	_workspace.set_menu_checked("domain", enabled)

func _set_lidar(visible: bool) -> void:
	if not _workspace:
		return
	_workspace.set_lidar_visible(visible)
	_set_menu_checked(_sensors_menu, MenuId.SENSOR_LIDAR, visible)
	_workspace.set_menu_checked("lidar", visible)
	_mark_scenario("lidar_active", visible)

func _set_camera(visible: bool) -> void:
	if not _workspace:
		return
	_workspace.set_camera_visible(visible)
	_set_menu_checked(_sensors_menu, MenuId.SENSOR_CAMERA, visible)
	_workspace.set_menu_checked("camera", visible)
	_mark_scenario("camera_active", visible)

func _set_imu(visible: bool) -> void:
	if not _workspace:
		return
	_workspace.set_imu_visible(visible)
	_set_menu_checked(_sensors_menu, MenuId.SENSOR_IMU, visible)
	_workspace.set_menu_checked("imu", visible)
	_mark_scenario("imu_active", visible)

func _toggle_terminal() -> void:
	_set_terminal_visible(not _terminal.visible)


func _set_terminal_visible(visible: bool) -> void:
	_terminal.visible = visible
	_workbench.dragger_visibility = SplitContainer.DRAGGER_VISIBLE if visible else SplitContainer.DRAGGER_HIDDEN
	_set_menu_checked(_view_menu, MenuId.VIEW_TERMINAL, visible)
	if visible:
		_terminal.focus_input()


func _on_wireframe_changed(enabled: bool) -> void:
	_set_menu_checked(_view_menu, MenuId.VIEW_WIREFRAME, enabled)


func _on_grid_changed(enabled: bool) -> void:
	_set_menu_checked(_view_menu, MenuId.VIEW_GRID, enabled)


func _set_menu_checked(menu: PopupMenu, id: int, checked: bool) -> void:
	var idx := menu.get_item_index(id)
	if idx >= 0:
		menu.set_item_checked(idx, checked)


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
	_cli.execute(line, _terminal.echo)


# ---------------------------------------------------------------- input / status

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _shortcuts and _dispatch_shortcut(_shortcuts.match_event(event)):
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_QUOTELEFT:
			_open_palette()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_P:
			_open_palette()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and not event.shift_pressed and event.keycode == KEY_K:
			_open_palette()
			get_viewport().set_input_as_handled()


## Dispatch a viewport shortcut action. Returns true if handled.
func _dispatch_shortcut(action: String) -> bool:
	if action.is_empty():
		return false
	var v := _viewer()
	match action:
		"mode_select":
			if v: v.set_mode(RobotViewerController.Mode.SELECT)
		"mode_translate":
			if v: v.set_mode(RobotViewerController.Mode.TRANSLATE)
		"mode_rotate":
			if v: v.set_mode(RobotViewerController.Mode.ROTATE)
		"toggle_render":
			if v: v.set_render_proper_meshes(not v.get_render_proper_meshes())
		"toggle_grid":
			_toggle_grid()
		"toggle_wireframe":
			_toggle_wireframe()
		_:
			return false
	return true


func _open_palette() -> void:
	if _command_palette and is_instance_valid(_command_palette):
		return
	_command_palette = CommandPalette.new()
	_command_palette.command_picked.connect(_on_command_picked)
	add_child(_command_palette)


func _on_command_picked(name: String) -> void:
	_terminal.set_input(name + " ")


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


func _on_joints_zeroed() -> void:
	_mark_scenario("all_joints_zeroed", true)


func _on_target_reached() -> void:
	_mark_scenario("end_effector_reached", true)


func _wire_scenario_service() -> void:
	var svc = get_node_or_null("/root/ScenarioService")
	if svc and svc.has_signal("scenario_changed"):
		svc.scenario_changed.connect(_on_scenario_changed)


func _on_scenario_changed(_id: String) -> void:
	var svc = get_node_or_null("/root/ScenarioService")
	if not svc or not svc.active:
		return
	match str(svc.active.setup):
		"arm6":
			_load_library_robot("arm6")
		"physics_demo":
			_open_demo("res://scenes/physics_demo.tscn", "Physics Demo")
		_:
			pass


func _load_library_robot(id: String) -> void:
	_ensure_panel("editor")
	var lib = get_node_or_null("/root/RobotLibrary")
	if lib and lib.has_method("build"):
		var robot = lib.build(id)
		if robot and _workspace:
			_workspace.load_robot_node(robot)
			_navigate("editor")


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
