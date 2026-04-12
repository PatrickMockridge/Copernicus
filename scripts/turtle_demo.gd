# turtle_demo.gd
# TurtleBot/TurtleSim demo showcasing modular navigation architecture
# Native A* mode and ROS2 turtlesim bridge mode

class_name TurtleDemo
extends Node3D

## Preload custom classes
const TurtleController = preload("res://scripts/turtle/turtle_controller.gd")
const OccupancyGrid = preload("res://scripts/nav/occupancy_grid.gd")
const AStarGridPlanner = preload("res://scripts/nav/astar_grid_planner.gd")
const PathVisualizer = preload("res://scripts/nav/path_visualizer.gd")

## UI elements
var _mode_label: Label
var _mode_button: Button
var _instructions: Label
var _status_label: Label
var _ui_container: Control

## Core components
var _turtle: TurtleController
var _occupancy_grid: OccupancyGrid
var _nav_planner: AStarGridPlanner
var _path_visualizer: PathVisualizer
var _camera: Camera3D
var _cam_pivot: Node3D

## State
var _current_mode: int = TurtleController.Mode.NATIVE
var _ros2_connected: bool = false
var _click_target: MeshInstance3D

## Arena bounds
var _arena_min: Vector3 = Vector3(-5, 0, -5)
var _arena_max: Vector3 = Vector3(5, 0, 5)
var _arena_resolution: float = 0.1


func _ready() -> void:
	_setup_environment()
	_setup_turtle()
	_setup_occupancy_grid()
	_setup_nav_planner()
	_setup_path_visualizer()
	_setup_ui()
	print("TurtleDemo: Ready - Click on ground to navigate!")


func _setup_environment() -> void:
	# Camera pivot for orbit-style following
	_cam_pivot = Node3D.new()
	_cam_pivot.set_name("CameraPivot")
	add_child(_cam_pivot)

	_camera = Camera3D.new()
	_camera.set_name("MainCamera")
	_camera.fov = 60
	_cam_pivot.add_child(_camera)

	# Lighting
	var ambient = DirectionalLight3D.new()
	ambient.set_name("AmbientLight")
	ambient.light_color = Color(0.4, 0.4, 0.5)
	ambient.light_energy = 0.4
	ambient.rotation_degrees = Vector3(-45, 30, 0)
	add_child(ambient)

	var key_light = DirectionalLight3D.new()
	key_light.set_name("KeyLight")
	key_light.light_color = Color(1.0, 0.98, 0.95)
	key_light.light_energy = 0.9
	key_light.rotation_degrees = Vector3(-45, -45, 0)
	key_light.shadow_enabled = true
	add_child(key_light)

	# Ground plane
	var ground = StaticBody3D.new()
	ground.set_name("Ground")
	var ground_collision = CollisionShape3D.new()
	ground_collision.shape = PlaneShape3D.new()
	ground.add_child(ground_collision)

	var ground_mesh = MeshInstance3D.new()
	ground_mesh.set_name("GroundMesh")
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(12, 12)
	ground_mesh.mesh = plane_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.28, 0.32)
	ground_mat.roughness = 0.9
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	add_child(ground)

	# Click target indicator (small sphere)
	_click_target = MeshInstance3D.new()
	_click_target.set_name("ClickTarget")
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	_click_target.mesh = sphere
	var target_mat = StandardMaterial3D.new()
	target_mat.albedo_color = Color(1, 0.4, 0.2, 0.8)
	target_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_click_target.material_override = target_mat
	_click_target.visible = false
	add_child(_click_target)

	# Obstacles - walls and boxes
	_create_obstacles()

	_update_camera()


func _create_obstacles() -> void:
	# Boundary walls
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.4, 0.4, 0.45)

	# North wall
	_create_wall(Vector3(0, 0.15, -4.5), Vector3(8, 0.3, 0.2), wall_mat)
	# South wall
	_create_wall(Vector3(0, 0.15, 4.5), Vector3(8, 0.3, 0.2), wall_mat)
	# East wall
	_create_wall(Vector3(4.5, 0.15, 0), Vector3(0.2, 0.3, 8), wall_mat)
	# West wall
	_create_wall(Vector3(-4.5, 0.15, 0), Vector3(0.2, 0.3, 8), wall_mat)

	# Interior obstacles
	var box1_mat = StandardMaterial3D.new()
	box1_mat.albedo_color = Color(0.8, 0.3, 0.3)
	_create_box(Vector3(2, 0.15, 2), Vector3(0.6, 0.3, 0.6), box1_mat)

	var box2_mat = StandardMaterial3D.new()
	box2_mat.albedo_color = Color(0.3, 0.6, 0.8)
	_create_box(Vector3(-2, 0.1, -1.5), Vector3(0.5, 0.2, 0.5), box2_mat)

	var box3_mat = StandardMaterial3D.new()
	box3_mat.albedo_color = Color(0.7, 0.6, 0.2)
	_create_box(Vector3(1, 0.12, -3), Vector3(0.4, 0.24, 0.4), box3_mat)

	var box4_mat = StandardMaterial3D.new()
	box4_mat.albedo_color = Color(0.5, 0.4, 0.7)
	_create_box(Vector3(-3, 0.1, 2.5), Vector3(0.5, 0.2, 0.5), box4_mat)


func _create_wall(pos: Vector3, size: Vector3, mat: Material) -> void:
	var wall = StaticBody3D.new()
	wall.set_name("Wall")
	wall.position = pos

	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	wall.add_child(collision)

	var mesh = MeshInstance3D.new()
	mesh.set_name("WallMesh")
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = mat
	wall.add_child(mesh)

	add_child(wall)


func _create_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var box = StaticBody3D.new()
	box.set_name("Obstacle")
	box.position = pos

	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	box.add_child(collision)

	var mesh = MeshInstance3D.new()
	mesh.set_name("ObstacleMesh")
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = mat
	box.add_child(mesh)

	add_child(box)


func _setup_turtle() -> void:
	_turtle = TurtleController.new()
	_turtle.set_name("Turtle")
	_turtle.position = Vector3(0, 0.04, 0)
	add_child(_turtle)
	_turtle.navigation_finished.connect(_on_navigation_finished)


func _setup_occupancy_grid() -> void:
	_occupancy_grid = OccupancyGrid.new()

	# Get physics space for raycasting
	var space_state = get_world_3d().direct_space_state
	var bounds_min = Vector3(_arena_min.x, 0, _arena_min.z)
	var bounds_max = Vector3(_arena_max.x, 2, _arena_max.z)

	_occupancy_grid.from_scene(space_state, bounds_min, bounds_max, _arena_resolution)
	print("TurtleDemo: Occupancy grid created: ", _occupancy_grid.get_width(), "x", _occupancy_grid.get_height())


func _setup_nav_planner() -> void:
	_nav_planner = AStarGridPlanner.new()
	_nav_planner.initialize({
		"use_diagonals": false,
		"max_iterations": 1000,
		"robot_radius": 0.15,
		"smooth_path": true
	})
	_nav_planner.set_map(_occupancy_grid.to_dictionary())


func _setup_path_visualizer() -> void:
	_path_visualizer = PathVisualizer.new()
	_path_visualizer.set_name("PathVisualizer")
	add_child(_path_visualizer)


func _setup_ui() -> void:
	# UI container in top-left
	_ui_container = Control.new()
	_ui_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ui_container.position = Vector2(10, 10)
	_ui_container.custom_minimum_size = Vector2(280, 0)
	add_child(_ui_container)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size.y = 150
	_ui_container.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "TurtleBot Demo"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Mode info
	_mode_label = Label.new()
	_mode_label.text = "Mode: NATIVE (A* Grid)"
	_mode_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	vbox.add_child(_mode_label)

	# Status
	_status_label = Label.new()
	_status_label.text = "Click ground to navigate"
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(_status_label)

	# Mode toggle button
	_mode_button = Button.new()
	_mode_button.text = "Switch to ROS2 Mode"
	_mode_button.pressed.connect(_on_mode_button_pressed)
	vbox.add_child(_mode_button)

	# Instructions
	var sep = HSeparator.new()
	vbox.add_child(sep)

	_instructions = Label.new()
	_instructions.text = "Click anywhere on the ground.\nRobot will plan and follow path."
	_instructions.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_instructions)


func _on_mode_button_pressed() -> void:
	if _current_mode == TurtleController.Mode.NATIVE:
		switch_to_ros2_mode()
	else:
		switch_to_native_mode()


func switch_to_ros2_mode() -> void:
	_current_mode = TurtleController.Mode.ROS2
	_mode_label.text = "Mode: ROS2 (Turtlesim)"
	_mode_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	_mode_button.text = "Switch to Native Mode"
	_instructions.text = "ROS2 mode:\nConnect to turtlesim running in ROS2.\nClick to navigate real turtle."
	_status_label.text = "Checking ROS2..."

	# Check if Godot ROS2 is available
	var godot_ros2 = get_node_or_null("/root/GodotROS2")
	if godot_ros2 and godot_ros2.is_initialized():
		_ros2_connected = true
		_status_label.text = "ROS2 connected!"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_turtle.set_mode(TurtleController.Mode.ROS2)
		_setup_ros2_subscriptions()
	else:
		_ros2_connected = false
		_status_label.text = "ROS2 not available - run godot_ros2_bridge"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))


func switch_to_native_mode() -> void:
	_current_mode = TurtleController.Mode.NATIVE
	_mode_label.text = "Mode: NATIVE (A* Grid)"
	_mode_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_mode_button.text = "Switch to ROS2 Mode"
	_instructions.text = "Native mode:\nGodot A* path planning.\nClick to navigate."
	_status_label.text = "Click ground to navigate"
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_turtle.set_mode(TurtleController.Mode.NATIVE)
	_ros2_connected = false


func _setup_ros2_subscriptions() -> void:
	var godot_ros2 = get_node_or_null("/root/GodotROS2")
	if godot_ros2:
		# Subscribe to turtlesim pose
		var pose_sub = godot_ros2.create_subscription(
			"/turtle1/pose",
			"turtlesim/msg/Pose",
			Callable(self, "_on_turtlesim_pose")
		)
		print("TurtleDemo: Subscribed to /turtle1/pose")


func _on_turtlesim_pose(msg: Dictionary) -> void:
	# Update turtle position to match real turtlesim
	var x = msg.get("x", 0.0) / 100.0  # Convert from turtlesim coords
	var y = msg.get("y", 0.0) / 100.0
	var theta = msg.get("theta", 0.0)

	# Update visual turtle position
	_turtle.set_position(Vector3(x, 0.04, y))
	_turtle.set_rotation(-theta)

	_status_label.text = "Turtlesim: (%.1f, %.1f)" % [x, y]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = _raycast_to_ground(event.position)
		if click_pos != Vector3.INF:
			_show_click_target(click_pos)
			_navigate_to_goal(click_pos)


func _raycast_to_ground(screen_pos: Vector2) -> Vector3:
	var from = _camera.project_ray_origin(screen_pos)
	var to = from + _camera.project_ray_normal(screen_pos) * 100

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result = space_state.intersect_ray(query)
	if result and result.position.y < 1.0:
		return Vector3(result.position.x, 0.04, result.position.z)

	return Vector3.INF


func _show_click_target(pos: Vector3) -> void:
	_click_target.position = pos
	_click_target.visible = true


func _navigate_to_goal(goal: Vector3) -> void:
	var start = _turtle.get_position()

	# Check if goal is valid
	if not _nav_planner.is_valid_position(goal):
		_status_label.text = "Goal is in obstacle!"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		return

	_status_label.text = "Planning..."
	_nav_planner.planning_finished.connect(_on_planning_finished)

	var path = _nav_planner.plan(start, goal)


func _on_planning_finished(success: bool, path: Array) -> void:
	_nav_planner.planning_finished.disconnect(_on_planning_finished)

	if success and not path.is_empty():
		_status_label.text = "Path found: %d waypoints" % path.size()
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_path_visualizer.visualize_path(path)
		_turtle.navigate_along_path(path)
	else:
		_status_label.text = "No path found!"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))


func _on_navigation_finished() -> void:
	_status_label.text = "Navigation complete!"
	_path_visualizer.clear_path()


func _physics_process(delta: float) -> void:
	_update_camera()


func _update_camera() -> void:
	if _cam_pivot and _turtle:
		var target = _turtle.get_position()
		var offset = Vector3(0, 3, 4)
		_cam_pivot.position = target + offset
		_cam_pivot.look_at(target, Vector3.UP)


func _process(delta: float) -> void:
	# Hide click target after delay
	if _click_target.visible:
		var t = _click_target.get_meta("_hide_time", 0.0) as float
		t += delta
		_click_target.set_meta("_hide_time", t)
		if t > 2.0:
			_click_target.visible = false
