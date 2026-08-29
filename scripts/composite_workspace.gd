# composite_workspace.gd
# Unified workspace with 3D viewport and control panels side by side

class_name CompositeWorkspace
extends Control

signal robot_loaded(node: Node3D)
signal publish_requested(robot_name: String)
signal wireframe_changed(enabled: bool)
signal grid_changed(enabled: bool)

const RobotViewerController = preload("res://scripts/robot_viewer_controller.gd")
const JointPanel = preload("res://scripts/joint_panel.gd")
const PublishPanel = preload("res://scripts/publish_panel.gd")
const LidarDebug = preload("res://scripts/lidar_debug.gd")
const CameraDebug = preload("res://scripts/camera_debug.gd")
const ImuDebug = preload("res://scripts/imu_debug.gd")

var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _robot_viewer: RobotViewerController
var _panel_area: VBoxContainer
var _tab_container: TabContainer
var _joint_panel: JointPanel
var _status_label: Label
var _toolbar: ViewportToolbar
var _lidar_debug: LidarDebug
var _camera_debug: CameraDebug
var _imu_debug: ImuDebug


func _ready() -> void:
	_setup_workspace()


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
	_viewport_container.add_child(_toolbar)
	_toolbar.set_wireframe(false)
	_toolbar.set_grid(true)

	# ---- Panel area (right 30%) ----
	_panel_area = VBoxContainer.new()
	_panel_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_area.size_flags_stretch_ratio = 0.3
	_panel_area.custom_minimum_size.x = 280
	hbox.add_child(_panel_area)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_area.add_child(_tab_container)

	_joint_panel = JointPanel.new()
	_joint_panel.set_name("JointPanel")
	_tab_container.add_child(_joint_panel)
	_joint_panel.set_viewer(_robot_viewer)
	_tab_container.set_tab_title(0, "Joints")

	# Status bar
	var status_bar = HBoxContainer.new()
	_panel_area.add_child(status_bar)

	_status_label = Label.new()
	_status_label.text = "Robot: Demo"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	status_bar.add_child(_status_label)

	var publish_btn = Button.new()
	publish_btn.text = "Publish"
	publish_btn.pressed.connect(_on_publish_pressed)
	status_bar.add_child(publish_btn)


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
	if _status_label:
		_status_label.text = "Robot: " + robot_node.name
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


func load_urdf(path: String) -> void:
	if _robot_viewer:
		_robot_viewer.load_urdf(path)
		_status_label.text = "Robot: " + path.get_file()


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


func get_joint_panel() -> JointPanel:
	return _joint_panel


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
		_status_label.text = "Robot: " + path.get_file()


func load_robot_node(node: Node3D) -> void:
	if _robot_viewer:
		_robot_viewer.load_robot_node(node)
		_status_label.text = "Robot: " + node.name


func _process(_delta: float) -> void:
	if _toolbar:
		_toolbar.set_fps(Engine.get_frames_per_second())
	if _lidar_debug and _lidar_debug.visible and _robot_viewer.get_robot_root():
		_lidar_debug.scan()
