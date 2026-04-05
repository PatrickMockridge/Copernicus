# main.gd
# Robot Design POC - Main UI Controller
# Uses GameAI SDK for behavior generation + GodotROS2 SDK for simulation

extends Control

# ===== UI References =====
var _api_key_input: LineEdit
var _connect_btn: Button
var _status_label: Label
var _robot_type_input: OptionButton
var _sensors_input: TextEdit
var _generate_btn: Button
var _code_output: TextEdit
var _behavior_type: OptionButton

# ===== Simulation References =====
var _sim_viewport: SubViewport
var _sim_camera: Camera3D
var _sim: ROS2Simulator
var _robot: RobotModel
var _drive: DifferentialDrive

# ===== ROS2 References =====
var _bridge_connected: bool = false
var _connected_ai: bool = false
var _robot_spawned: bool = false
var _sim_paused: bool = false

# Publishers
var _odom_pub: Publisher
var _scan_pub: Publisher
var _imu_pub: Publisher

# Subscription
var _cmd_vel_sub: Subscription

# Sensor references
var _lidar: LidarSensor
var _imu: ImuSensor
var _camera: CameraSensor

# Mesh source toggle (0 = meshes, 1 = primitives)
var _mesh_source: int = 0


# ===== Lifecycle =====

func _ready() -> void:
	_setup_ui()


# ===== UI Setup =====

func _setup_ui() -> void:
	# Use full rect split: left panel (2D UI) + right viewport (3D simulation)
	var split = HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.dragger_rail_folder = ""
	add_child(split)

	# Left panel — scrollable 2D UI
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 420
	split.add_child(scroll)

	var panel = VBoxContainer.new()
	panel.custom_minimum_size.x = 400
	panel.add_theme_constant_override("separation", 16)
	scroll.add_child(panel)
	_setup_left_panel(panel)

	# Right side — 3D simulation viewport
	_setup_simulation_viewport(split)


func _setup_left_panel(panel: VBoxContainer) -> void:
	# Title
	var title = Label.new()
	title.text = "Robot Design AI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)

	var sub = Label.new()
	sub.text = "TurtleBot4 + ROS2 Simulation"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	panel.add_child(sub)

	panel.add_child(_make_sep())

	# Section 1: ROS2 Bridge
	panel.add_child(_make_section_header("1. ROS2 Bridge"))
	panel.add_child(_make_bridge_status())
	panel.add_child(_make_bridge_buttons())

	panel.add_child(_make_sep())

	# Section 2: Robot Spawn
	panel.add_child(_make_section_header("2. Spawn TurtleBot4"))
	panel.add_child(_make_mesh_source_selector())
	panel.add_child(_make_spawn_button())

	panel.add_child(_make_sep())

	# Section 3: Simulation Controls
	panel.add_child(_make_section_header("3. Simulation"))
	panel.add_child(_make_sim_controls())

	panel.add_child(_make_sep())

	# Section 4: AI API Connection
	panel.add_child(_make_section_header("4. AI API Connection"))
	panel.add_child(_make_api_section())

	panel.add_child(_make_sep())

	# Section 5: AI Behavior
	panel.add_child(_make_section_header("5. AI Behavior"))
	panel.add_child(_make_ai_section())

	panel.add_child(_make_sep())

	# Section 6: ROS2 Topics
	panel.add_child(_make_section_header("6. ROS2 Topics"))
	panel.add_child(_make_topic_list())

	panel.add_child(_make_sep())

	# Section 7: Generated Code
	panel.add_child(_make_section_header("7. Generated Code"))
	panel.add_child(_make_code_section())


func _setup_simulation_viewport(split: HSplitContainer) -> void:
	var container = SubViewportContainer.new()
	container.stretch = true
	split.add_child(container)

	_sim_viewport = SubViewport.new()
	_sim_viewport.world_3d = World3D.new()
	_sim_viewport.handle_input_locally = true
	_sim_viewport.size = Vector2i(800, 600)
	container.add_child(_sim_viewport)

	# Lighting
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	_sim_viewport.add_child(sun)

	var ambient = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	ambient.environment = env
	_sim_viewport.add_child(ambient)

	# Camera
	_sim_camera = Camera3D.new()
	_sim_camera.position = Vector3(1.5, 2.0, 1.5)
	_sim_camera.look_at(Vector3(0, 0, 0))
	_sim_viewport.add_child(_sim_camera)

	# Ground plane (visual)
	var ground_mesh = MeshInstance3D.new()
	ground_mesh.mesh = BoxMesh.new()
	ground_mesh.mesh.size = Vector3(10, 0.01, 10)
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.2, 0.2, 0.22)
	ground_mat.roughness = 0.9
	ground_mesh.material_override = ground_mat
	ground_mesh.position = Vector3(0, -0.005, 0)
	_sim_viewport.add_child(ground_mesh)

	# Grid helper — create a 10x10 line grid using ImmediateMesh3D
	var grid_mesh = ImmediateMesh.new()
	var grid_node = MeshInstance3D.new()
	grid_node.mesh = grid_mesh
	grid_node.position = Vector3(0, 0.001, 0)
	var grid_mat = StandardMaterial3D.new()
	grid_mat.albedo_color = Color(0.3, 0.3, 0.4, 0.6)
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_node.material_override = grid_mat
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-5, 6):
		grid_mesh.surface_add_vertex(Vector3(i, 0, -5))
		grid_mesh.surface_add_vertex(Vector3(i, 0, 5))
		grid_mesh.surface_add_vertex(Vector3(-5, 0, i))
		grid_mesh.surface_add_vertex(Vector3(5, 0, i))
	grid_mesh.surface_end()
	_sim_viewport.add_child(grid_node)

	# Simulator (not yet added to viewport tree until robot spawns)
	_sim = ROS2Simulator.new()
	_sim.set_mode(ROS2Simulator.Mode.SIMPLE)
	_sim.set_gravity(Vector3(0, -9.81, 0))


# ===== UI Component Factories =====

func _make_section_header(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	return lbl


func _make_sep() -> HSeparator:
	var sep = HSeparator.new()
	sep.custom_minimum_size.y = 1
	sep.modulate = Color(0.3, 0.3, 0.35)
	return sep


func _make_bridge_status() -> Label:
	var lbl = Label.new()
	lbl.name = "bridge_status"
	lbl.text = "Bridge: Not connected"
	lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	_status_label = lbl
	return lbl


func _make_api_section() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "API Key:"
	hbox.add_child(lbl)

	_api_key_input = LineEdit.new()
	_api_key_input.placeholder_text = "sk-ant-..."
	_api_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_api_key_input.secret = true
	hbox.add_child(_api_key_input)

	var connect_ai_btn = Button.new()
	connect_ai_btn.text = "Connect AI"
	connect_ai_btn.pressed.connect(_on_connect_pressed)
	hbox.add_child(connect_ai_btn)

	vbox.add_child(hbox)

	_connect_btn = connect_ai_btn
	return vbox


func _make_bridge_buttons() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var connect_btn = Button.new()
	connect_btn.text = "Connect Bridge"
	connect_btn.pressed.connect(_on_connect_bridge_pressed)
	hbox.add_child(connect_btn)

	var launch_btn = Button.new()
	launch_btn.text = "Launch Bridge"
	launch_btn.pressed.connect(_on_launch_bridge_pressed)
	hbox.add_child(launch_btn)

	return hbox


func _make_mesh_source_selector() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "Mesh source:"
	hbox.add_child(lbl)

	var opt = OptionButton.new()
	opt.add_item("DAE Meshes (ROS packages)", 0)
	opt.add_item("Godot Primitives", 1)
	opt.item_selected.connect(_on_mesh_source_selected)
	hbox.add_child(opt)
	opt.name = "mesh_source_opt"
	return hbox


func _make_spawn_button() -> Button:
	var btn = Button.new()
	btn.text = "Spawn TurtleBot4"
	btn.pressed.connect(_on_spawn_turtlebot_pressed)
	return btn


func _make_sim_controls() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var play_btn = Button.new()
	play_btn.text = "Play"
	play_btn.pressed.connect(_on_sim_play_pressed)
	play_btn.name = "sim_play_btn"
	hbox.add_child(play_btn)

	var pause_btn = Button.new()
	pause_btn.text = "Pause"
	pause_btn.pressed.connect(_on_sim_pause_pressed)
	pause_btn.name = "sim_pause_btn"
	hbox.add_child(pause_btn)

	var reset_btn = Button.new()
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(_on_sim_reset_pressed)
	hbox.add_child(reset_btn)

	return hbox


func _make_ai_section() -> VBoxContainer:
	var vbox = VBoxContainer.new()

	var grid = GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)

	var type_lbl = Label.new()
	type_lbl.text = "Robot:"
	grid.add_child(type_lbl)

	var type_drop = OptionButton.new()
	type_drop.add_item("TurtleBot4", 0)
	type_drop.add_item("Differential Drive", 1)
	type_drop.add_item("Custom", 2)
	grid.add_child(type_drop)
	_robot_type_input = type_drop

	var sens_lbl = Label.new()
	sens_lbl.text = "Sensors:"
	grid.add_child(sens_lbl)

	var sens_text = TextEdit.new()
	sens_text.custom_minimum_size.y = 50
	sens_text.text = "lidar, camera, imu"
	grid.add_child(sens_text)
	_sensors_input = sens_text

	var beh_lbl = Label.new()
	beh_lbl.text = "Behavior:"
	grid.add_child(beh_lbl)

	var beh_drop = OptionButton.new()
	beh_drop.add_item("Obstacle Avoidance", 0)
	beh_drop.add_item("Wall Following", 1)
	beh_drop.add_item("Patrol", 2)
	beh_drop.add_item("Chase", 3)
	beh_drop.add_item("Flee", 4)
	grid.add_child(beh_drop)
	_behavior_type = beh_drop

	_generate_btn = Button.new()
	_generate_btn.text = "Generate with AI"
	_generate_btn.pressed.connect(_on_generate_pressed)
	_generate_btn.disabled = true
	vbox.add_child(_generate_btn)

	return vbox


func _make_topic_list() -> VBoxContainer:
	var vbox = VBoxContainer.new()

	var topics = [
		"/turtlebot4/odom       nav_msgs/Odometry",
		"/turtlebot4/scan       sensor_msgs/LaserScan",
		"/turtlebot4/imu        sensor_msgs/Imu",
		"/turtlebot4/cmd_vel    geometry_msgs/Twist  (sub)",
	]
	for t in topics:
		var lbl = Label.new()
		lbl.text = "  " + t
		lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		vbox.add_child(lbl)

	return vbox


func _make_code_section() -> VBoxContainer:
	var vbox = VBoxContainer.new()

	_code_output = TextEdit.new()
	_code_output.custom_minimum_size.y = 150
	_code_output.editable = false
	_code_output.scroll_following = true
	_code_output.text = "# AI-generated behavior will appear here..."
	vbox.add_child(_code_output)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var copy_btn = Button.new()
	copy_btn.text = "Copy"
	copy_btn.pressed.connect(_on_copy_pressed)
	hbox.add_child(copy_btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_pressed)
	hbox.add_child(clear_btn)

	vbox.add_child(hbox)
	return vbox


# ===== UI Event Handlers =====

func _on_mesh_source_selected(index: int) -> void:
	_mesh_source = index


async func _on_connect_bridge_pressed() -> void:
	if GodotROS2.is_initialized():
		_status_label.text = "Already connected"
		return

	_status_label.text = "Connecting to bridge..."
	var ok = await GodotROS2.initialize("turtlebot4_godot", "/turtlebot4", "127.0.0.1")

	if GodotROS2.is_bridge_connected():
		_bridge_connected = true
		_status_label.text = "Bridge connected!"
		_update_bridge_status_ui(true)
		_setup_ros2_topics()
	else:
		_bridge_connected = false
		_status_label.text = "Bridge connection failed (is bridge node running?)"
		_update_bridge_status_ui(false)


func _on_launch_bridge_pressed() -> void:
	_status_label.text = "Start bridge with: ros2 run godot_ros2_bridge godot_bridge_node"
	_status_label.text += "\nThen click 'Connect Bridge'"


func _on_spawn_turtlebot_pressed() -> void:
	if _robot_spawned:
		_status_label.text = "Robot already spawned"
		return

	_status_label.text = "Spawning TurtleBot4..."

	var source: TurtleBot4Loader.MeshSource = (
		TurtleBot4Loader.MeshSource.MESHES if _mesh_source == 0
		else TurtleBot4Loader.MeshSource.PRIMITIVES
	)

	_robot = TurtleBot4Loader.load_turtlebot4("standard", source)
	if _robot == null:
		_status_label.text = "Failed to create robot model"
		return

	# Find sensors
	for child in _robot.get_node().get_children():
		if child is LidarSensor:
			_lidar = child
		elif child is ImuSensor:
			_imu = child
		elif child is CameraSensor:
			_camera = child
		elif child is DifferentialDrive:
			_drive = child

	# Set initial pose
	_robot.set_global_transform(Transform3D(Basis(), Vector3(0, 0, 0)))

	# Add to simulator
	_sim.add_robot(_robot)

	# Add simulator to viewport (if not already)
	if not _sim_viewport.has_node("ROS2Simulator"):
		_sim_viewport.add_child(_sim)

	_robot_spawned = true
	_status_label.text = "TurtleBot4 spawned (%s)!" % (
		"meshes" if _mesh_source == 0 else "primitives"
	)

	# Auto-connect bridge if not already
	if GodotROS2.is_initialized() and not _bridge_connected:
		_setup_ros2_topics()


func _setup_ros2_topics() -> void:
	if not _robot_spawned or not GodotROS2.is_bridge_connected():
		return

	var node = GodotROS2.get_ros_node()

	# Publishers
	_odom_pub = node.create_publisher("/turtlebot4/odom", "nav_msgs/Odometry")
	_scan_pub = node.create_publisher("/turtlebot4/scan", "sensor_msgs/LaserScan")
	_imu_pub = node.create_publisher("/turtlebot4/imu", "sensor_msgs/Imu")

	# Subscriber — cmd_vel drives the differential drive
	_cmd_vel_sub = node.create_subscription(
		"/turtlebot4/cmd_vel",
		"geometry_msgs/Twist",
		_on_cmd_vel_received
	)

	print("ROS2 topics wired: /turtlebot4/odom, /scan, /imu (pub) + /cmd_vel (sub)")


func _on_cmd_vel_received(msg: Dictionary) -> void:
	# Drive the robot with velocity commands
	# geometry_msgs/Twist: {linear: {x, y, z}, angular: {x, y, z}}
	if _drive == null:
		return

	var linear_x = msg.get("linear", {}).get("x", 0.0)
	var angular_z = msg.get("angular", {}).get("z", 0.0)

	# Differential drive: v = linear_x, omega = angular_z
	# left_vel = (v - omega * separation / 2) / radius
	# right_vel = (v + omega * separation / 2) / radius
	var separation = 0.233  # WHEEL_SEPARATION
	var radius = 0.0419    # WHEEL_RADIUS
	var left_vel = (linear_x - angular_z * separation * 0.5) / radius
	var right_vel = (linear_x + angular_z * separation * 0.5) / radius

	_drive.set_velocities(left_vel, right_vel)


func _on_sim_play_pressed() -> void:
	if not _robot_spawned:
		_status_label.text = "Spawn a robot first"
		return
	_sim_paused = false
	_sim.resume()
	_status_label.text = "Simulation running"


func _on_sim_pause_pressed() -> void:
	_on_sim_pause()
	_status_label.text = "Simulation paused"


func _on_sim_reset_pressed() -> void:
	_sim.reset()
	if _robot:
		_robot.set_global_transform(Transform3D(Basis(), Vector3(0, 0, 0)))
	_status_label.text = "Simulation reset"


func _on_sim_pause() -> void:
	_sim.pause()
	_sim_paused = true


func _update_bridge_status_ui(connected: bool) -> void:
	var status_lbl = _find_child_by_name(get_node("/root"), "bridge_status") as Label
	if status_lbl == null:
		# Try finding in the panel children
		for child in get_children():
			if child is ScrollContainer:
				var panel = child.get_child(0)
				status_lbl = _find_child_by_name(panel, "bridge_status")
				break
	if status_lbl:
		if connected:
			status_lbl.text = "Bridge: Connected"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		else:
			status_lbl.text = "Bridge: Disconnected"
			status_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))


func _find_child_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found = _find_child_by_name(child, name)
		if found:
			return found
	return null


# ===== AI Behavior Generation =====

async async func _on_generate_pressed() -> void:
	if not _connected_ai:
		_status_label.text = "Error: Not connected to AI"
		return

	_generate_btn.disabled = true
	_generate_btn.text = "Generating..."
	_code_output.text = "# Generating robot behavior...\n"

	var behaviors = ["obstacle_avoid", "wall_follow", "patrol", "chase", "flee"]
	var behavior = behaviors[_behavior_type.selected]
	var sensors_text = _sensors_input.text.strip_edges()

	_status_label.text = "Generating %s for TurtleBot4..." % behavior

	ROSAI.set_ai(GameAI)
	var result = await ROSAI.generate_behavior(behavior, {
		"robot_type": "TurtleBot4",
		"sensors": sensors_text.split(", ")
	})

	if result.is_ok():
		_code_output.text = result.ok_value().content
		_status_label.text = "Generation complete!"
	else:
		_code_output.text = "# Error: " + str(result.err_value())
		_status_label.text = "Generation failed"

	_generate_btn.disabled = false
	_generate_btn.text = "Generate with AI"


func _on_connect_pressed() -> void:
	var api_key = _api_key_input.text.strip_edges() if _api_key_input else ""
	if api_key == "":
		_status_label.text = "Error: Please enter API key"
		return

	_status_label.text = "Connecting to Anthropic..."
	GameAI.configure({
		"anthropic": {"api_key": api_key},
		"default": "anthropic"
	})

	var test_result = await GameAI.chat([{"role": "user", "content": "Hello"}])

	if test_result.is_ok():
		_connected_ai = true
		_generate_btn.disabled = false
		_status_label.text = "Connected to Claude!"
	else:
		_connected_ai = false
		_status_label.text = "Connection failed"


func _on_copy_pressed() -> void:
	if _code_output and _code_output.text:
		DisplayServer.clipboard_set(_code_output.text)
		_status_label.text = "Code copied!"


func _on_clear_pressed() -> void:
	if _code_output:
		_code_output.text = "# AI-generated behavior will appear here..."
	_status_label.text = "Cleared"


func _on_apply_pressed() -> void:
	_status_label.text = "Apply not yet implemented"


# ===== Main Loop =====

func _process(delta: float) -> void:
	# ROS2 spin — process subscription callbacks
	if GodotROS2 and GodotROS2.is_initialized():
		GodotROS2.get_executor().spin_some(delta)

		# Publish sensor data if robot is spawned
		if _robot_spawned and not _sim_paused:
			_publish_sensor_data(delta)

	# Step physics simulation
	if _robot_spawned and not _sim_paused:
		_sim.step_physics(delta)

		# Update differential drive
		if _drive:
			_drive.update(delta)


func _publish_sensor_data(delta: float) -> void:
	if not _robot:
		return

	# Odometry
	if _odom_pub:
		var pose = _robot.get_pose()
		var header = StdMsgs.create_header_now("odom")
		var odom_msg = NavMsgs.create_odometry_from_gd(
			header,
			"base_link",
			pose["position"],
			pose["orientation"],
			Vector3.ZERO,
			Vector3.ZERO
		)
		_odom_pub.publish(odom_msg)

	# Lidar scan
	if _scan_pub and _lidar:
		var header = StdMsgs.create_header_now("rplidar_link")
		# Use LidarSensor's scan data if available, otherwise empty
		var scan_msg = SensorMsgs.create_laserscan(
			header, -PI, PI, 0.005, 0.0, 0.01, 0.01,
			12.0, [], []
		)
		_scan_pub.publish(scan_msg)

	# IMU
	if _imu_pub and _imu:
		var header = StdMsgs.create_header_now("imu_link")
		var imu_msg = SensorMsgs.create_imu_from_gd(
			header,
			Quaternion.IDENTITY,
			Vector3.ZERO,
			Vector3.ZERO
		)
		_imu_pub.publish(imu_msg)
