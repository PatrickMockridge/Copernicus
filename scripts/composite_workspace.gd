# composite_workspace.gd
# Unified workspace with 3D viewport and control panels side by side

class_name CompositeWorkspace
extends Control

signal robot_loaded(node: Node3D)
signal publish_requested(robot_name: String)
signal wireframe_changed(enabled: bool)
signal grid_changed(enabled: bool)
## Shell-level requests originating from the viewport context menu or shortcuts.
signal viewport_action(id: String)

const RobotViewerController = preload("res://scripts/robot_viewer_controller.gd")
const PublishPanel = preload("res://scripts/publish_panel.gd")
const LidarDebug = preload("res://scripts/lidar_debug.gd")
const CameraDebug = preload("res://scripts/camera_debug.gd")
const ImuDebug = preload("res://scripts/imu_debug.gd")

## Context-menu item ids (viewport-owned).
enum CtxMenu {
	MODE_SELECT, MODE_TRANSLATE, MODE_ROTATE,
	RESET_VIEW, LOAD_ROBOT, WIREFRAME, GRID, RENDER,
	LIDAR, CAMERA, IMU, DOMAIN,
}

var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _robot_viewer: RobotViewerController
var _toolbar: ViewportToolbar
var _lidar_debug: LidarDebug
var _camera_debug: CameraDebug
var _imu_debug: ImuDebug
var _context_menu: PanelContainer
var _menu_widgets: Dictionary = {}   # CtxMenu id -> CheckBox (checkable items)
var _syncing_menu := false


func _ready() -> void:
	_setup_workspace()
	_setup_context_menu()


func _setup_workspace() -> void:
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# ---- 3D Viewport (left 70%) ----
	_viewport_container = SubViewportContainer.new()
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_stretch_ratio = 0.7
	hbox.add_child(_viewport_container)

	_sub_viewport = SubViewport.new()
	_viewport_container.stretch = true
	_viewport_container.add_child(_sub_viewport)

	_world_setup()

	_robot_viewer = RobotViewerController.new()
	_robot_viewer.set_name("RobotViewer")
	_robot_viewer.robot_loaded.connect(_on_robot_loaded)
	_robot_viewer.context_menu_requested.connect(_on_context_menu_requested)
	_robot_viewer.viewport_left_clicked.connect(_on_viewport_left_clicked)
	_sub_viewport.add_child(_robot_viewer)

	# ---- Sensor debug (hidden by default; toggled via View menu) ----
	_lidar_debug = LidarDebug.new()
	_lidar_debug.set_name("LidarDebug")
	_lidar_debug.visible = false
	_robot_viewer.add_child(_lidar_debug)

	_camera_debug = CameraDebug.new()
	_camera_debug.set_name("CameraDebug")
	_camera_debug.visible = false
	_robot_viewer.add_child(_camera_debug)

	_imu_debug = ImuDebug.new()
	_imu_debug.set_name("ImuDebug")
	_imu_debug.visible = false
	_robot_viewer.add_child(_imu_debug)

	# ---- Toolbar overlay on viewport ----
	_toolbar = ViewportToolbar.new()
	_toolbar.wireframe_clicked.connect(func() -> void: set_wireframe(not _robot_viewer.is_show_debug()))
	_toolbar.grid_clicked.connect(func() -> void: set_grid(not _robot_viewer.is_grid_visible()))
	_toolbar.reset_view.connect(_robot_viewer.reset_view)
	_toolbar.zero_clicked.connect(_robot_viewer.zero_all_joints)
	_toolbar.reach_clicked.connect(_robot_viewer.solve_ik_to_target)
	_toolbar.publish_clicked.connect(_on_publish_pressed)
	_viewport_container.add_child(_toolbar)
	_toolbar.set_wireframe(false)
	_toolbar.set_grid(true)


func _world_setup() -> void:
	var world = World3D.new()
	_sub_viewport.world_3d = world

	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.15, 0.18)
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.5
	env_node.environment = env
	_sub_viewport.add_child(env_node)


func _on_robot_loaded(robot_node: Node3D) -> void:
	if _lidar_debug:
		_lidar_debug.set_robot(robot_node)
	if _camera_debug:
		_camera_debug.set_robot(robot_node)
		if _robot_viewer.get_camera():
			_camera_debug.set_camera(_robot_viewer.get_camera())
	if _imu_debug:
		_imu_debug.set_robot(robot_node)
	robot_loaded.emit(robot_node)


func _on_publish_pressed() -> void:
	var robot_name := ""
	if _robot_viewer and _robot_viewer.get_robot_root():
		robot_name = _robot_viewer.get_robot_root().name
	publish_requested.emit(robot_name)


# ---------------------------------------------------------------- context menu

func _setup_context_menu() -> void:
	_context_menu = PanelContainer.new()
	_context_menu.visible = false
	_context_menu.z_index = 100
	_context_menu.add_theme_constant_override("separation", 4)

	var vbox := VBoxContainer.new()
	_context_menu.add_child(vbox)

	# Title bar with a top-right close button.
	var title := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = "Viewport"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(title_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(_hide_context_menu)
	title.add_child(close_btn)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	# Modes — a radio group keeps exactly one selected.
	var mode_group := ButtonGroup.new()
	_add_check_item(vbox, "Select", CtxMenu.MODE_SELECT, mode_group)
	_add_check_item(vbox, "Translate", CtxMenu.MODE_TRANSLATE, mode_group)
	_add_check_item(vbox, "Rotate", CtxMenu.MODE_ROTATE, mode_group)
	vbox.add_child(HSeparator.new())

	_add_action_item(vbox, "Reset View", CtxMenu.RESET_VIEW)
	_add_action_item(vbox, "Load Robot…", CtxMenu.LOAD_ROBOT)
	vbox.add_child(HSeparator.new())

	_add_check_item(vbox, "Wireframe", CtxMenu.WIREFRAME)
	_add_check_item(vbox, "Grid", CtxMenu.GRID)
	_add_check_item(vbox, "Render: Meshes", CtxMenu.RENDER)
	vbox.add_child(HSeparator.new())

	_add_check_item(vbox, "Lidar", CtxMenu.LIDAR)
	_add_check_item(vbox, "Camera Frustum", CtxMenu.CAMERA)
	_add_check_item(vbox, "IMU Axes", CtxMenu.IMU)
	_add_check_item(vbox, "Domain Randomization", CtxMenu.DOMAIN)

	add_child(_context_menu)


func _add_check_item(parent: Control, label: String, id: int, group: ButtonGroup = null) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.focus_mode = Control.FOCUS_NONE
	if group:
		cb.button_group = group
	cb.toggled.connect(_on_menu_toggled.bind(id))
	_menu_widgets[id] = cb
	parent.add_child(cb)


func _add_action_item(parent: Control, label: String, id: int) -> void:
	var btn := Button.new()
	btn.text = label
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_menu_action.bind(id))
	parent.add_child(btn)


func _on_context_menu_requested() -> void:
	if _context_menu.visible:
		_context_menu.hide()
		return
	_sync_context_menu()
	_context_menu.reset_size()
	var pos := get_global_mouse_position()
	var vs := get_viewport_rect().size
	var ms := _context_menu.size
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vs.x - ms.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, vs.y - ms.y - 4.0))
	_context_menu.global_position = pos
	_context_menu.show()


func _hide_context_menu() -> void:
	_context_menu.hide()


func _on_viewport_left_clicked() -> void:
	if _context_menu and _context_menu.visible:
		_context_menu.hide()


func _sync_context_menu() -> void:
	_sync_mode_checks()
	_set_widget_pressed(CtxMenu.RENDER, _robot_viewer.get_render_proper_meshes())
	_set_widget_pressed(CtxMenu.WIREFRAME, is_wireframe())
	_set_widget_pressed(CtxMenu.GRID, is_grid())
	_set_widget_pressed(CtxMenu.LIDAR, is_lidar_visible())
	_set_widget_pressed(CtxMenu.CAMERA, is_camera_visible())
	_set_widget_pressed(CtxMenu.IMU, is_imu_visible())
	_set_widget_pressed(CtxMenu.DOMAIN, is_domain_randomization_enabled())


func _sync_mode_checks() -> void:
	var m := _robot_viewer.get_mode()
	_set_widget_pressed(CtxMenu.MODE_SELECT, m == RobotViewerController.Mode.SELECT)
	_set_widget_pressed(CtxMenu.MODE_TRANSLATE, m == RobotViewerController.Mode.TRANSLATE)
	_set_widget_pressed(CtxMenu.MODE_ROTATE, m == RobotViewerController.Mode.ROTATE)


func _set_widget_pressed(id: int, pressed: bool) -> void:
	if not _menu_widgets.has(id):
		return
	_syncing_menu = true
	(_menu_widgets[id] as CheckBox).button_pressed = pressed
	_syncing_menu = false


func _on_menu_toggled(pressed: bool, id: int) -> void:
	if _syncing_menu:
		return
	# Modes are a radio group; only act on the newly-selected one.
	if id in [CtxMenu.MODE_SELECT, CtxMenu.MODE_TRANSLATE, CtxMenu.MODE_ROTATE]:
		if pressed:
			_handle_menu_id(id)
		return
	_handle_menu_id(id)


func _on_menu_action(id: int) -> void:
	_handle_menu_id(id)
	# One-shot actions dismiss the menu; checkboxes keep it open.
	if id in [CtxMenu.RESET_VIEW, CtxMenu.LOAD_ROBOT]:
		_context_menu.hide()


func _handle_menu_id(id: int) -> void:
	match id:
		CtxMenu.MODE_SELECT:
			_robot_viewer.set_mode(RobotViewerController.Mode.SELECT)
		CtxMenu.MODE_TRANSLATE:
			_robot_viewer.set_mode(RobotViewerController.Mode.TRANSLATE)
		CtxMenu.MODE_ROTATE:
			_robot_viewer.set_mode(RobotViewerController.Mode.ROTATE)
		CtxMenu.RESET_VIEW:
			_robot_viewer.reset_view()
		CtxMenu.LOAD_ROBOT:
			viewport_action.emit("load_robot")
		CtxMenu.WIREFRAME:
			viewport_action.emit("wireframe")
		CtxMenu.GRID:
			viewport_action.emit("grid")
		CtxMenu.RENDER:
			_robot_viewer.set_render_proper_meshes(not _robot_viewer.get_render_proper_meshes())
		CtxMenu.LIDAR:
			viewport_action.emit("lidar")
		CtxMenu.CAMERA:
			viewport_action.emit("camera")
		CtxMenu.IMU:
			viewport_action.emit("imu")
		CtxMenu.DOMAIN:
			viewport_action.emit("domain")


func load_urdf(path: String) -> void:
	if _robot_viewer:
		_robot_viewer.load_urdf(path)


func get_robot_viewer() -> RobotViewerController:
	return _robot_viewer


func set_wireframe(enabled: bool) -> void:
	if _robot_viewer:
		_robot_viewer.set_show_debug(enabled)
	if _toolbar:
		_toolbar.set_wireframe(enabled)
	wireframe_changed.emit(enabled)


func set_grid(enabled: bool) -> void:
	if _robot_viewer:
		_robot_viewer.set_grid_visible(enabled)
	if _toolbar:
		_toolbar.set_grid(enabled)
	grid_changed.emit(enabled)


func is_wireframe() -> bool:
	return _robot_viewer != null and _robot_viewer.is_show_debug()


func is_grid() -> bool:
	return _robot_viewer != null and _robot_viewer.is_grid_visible()


func set_lidar_visible(visible: bool) -> void:
	if not _lidar_debug:
		return
	_lidar_debug.visible = visible
	_lidar_debug.set_debug_visible(visible)
	if visible and _robot_viewer.get_robot_root():
		_lidar_debug.set_robot(_robot_viewer.get_robot_root())
		_lidar_debug.scan()


func set_camera_visible(visible: bool) -> void:
	if not _camera_debug:
		return
	_camera_debug.visible = visible
	_camera_debug.set_frustum_visible(visible)
	if visible:
		_camera_debug.update_frustum()


func set_imu_visible(visible: bool) -> void:
	if not _imu_debug:
		return
	_imu_debug.visible = visible
	_imu_debug.set_axes_visible(visible)


func set_domain_randomization(enabled: bool) -> void:
	if _robot_viewer:
		_robot_viewer.enable_domain_randomization(enabled)


func is_domain_randomization_enabled() -> bool:
	return _robot_viewer != null and _robot_viewer.is_domain_randomization_enabled()


func is_lidar_visible() -> bool:
	return _lidar_debug != null and _lidar_debug.visible


func is_camera_visible() -> bool:
	return _camera_debug != null and _camera_debug.visible


func is_imu_visible() -> bool:
	return _imu_debug != null and _imu_debug.visible


func load_mjcf(path: String) -> void:
	if _robot_viewer:
		_robot_viewer.load_mjcf(path)


func load_robot_node(node: Node3D) -> void:
	if _robot_viewer:
		_robot_viewer.load_robot_node(node)


func _process(_delta: float) -> void:
	if _toolbar:
		_toolbar.set_fps(Engine.get_frames_per_second())
	if _lidar_debug and _lidar_debug.visible and _robot_viewer.get_robot_root():
		_lidar_debug.scan()
