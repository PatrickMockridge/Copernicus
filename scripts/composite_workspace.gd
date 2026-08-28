# composite_workspace.gd
# Unified workspace with 3D viewport and control panels side by side

class_name CompositeWorkspace
extends Control

signal robot_loaded(node: Node3D)

const RobotViewerController = preload("res://scripts/robot_viewer_controller.gd")
const JointPanel = preload("res://scripts/joint_panel.gd")

var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _robot_viewer: RobotViewerController
var _panel_area: VBoxContainer
var _tab_container: TabContainer
var _joint_panel: JointPanel
var _status_label: Label
var _toolbar: ViewportToolbar


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

	# ---- Toolbar overlay on viewport ----
	_toolbar = ViewportToolbar.new()
	_toolbar.wireframe_toggled.connect(_robot_viewer.set_show_debug)
	_toolbar.grid_toggled.connect(_robot_viewer.set_grid_visible)
	_toolbar.reset_view.connect(_robot_viewer.reset_view)
	_viewport_container.add_child(_toolbar)

	# ---- Panel area (right 30%) ----
	_panel_area = VBoxContainer.new()
	_panel_area.size_flags_horizontal = Control.SIZE_FILL
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
	_status_label.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_SMALL)
	status_bar.add_child(_status_label)


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
	robot_loaded.emit(robot_node)


func load_urdf(path: String) -> void:
	if _robot_viewer:
		_robot_viewer.load_urdf(path)
		_status_label.text = "Robot: " + path.get_file()


func get_robot_viewer() -> RobotViewerController:
	return _robot_viewer


func get_joint_panel() -> JointPanel:
	return _joint_panel


func _process(_delta: float) -> void:
	if _toolbar:
		_toolbar.set_fps(Engine.get_frames_per_second())
