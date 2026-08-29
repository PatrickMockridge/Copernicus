# robot_viewer_controller.gd
# 3D viewer controller for robot models
# Provides camera controls, robot loading, and joint visualization

class_name RobotViewerController
extends Node3D

signal robot_loaded(node: Node3D)
signal joint_changed(joint_name: String, position: float)

const URDFToGodot = preload("res://scripts/urdf_to_godot.gd")

var _robot_root: Node3D
var _camera: Camera3D
var _cam_pivot: Node3D
var _cam_distance: float = 3.0
var _cam_yaw: float = 0.0
var _cam_pitch: float = 30.0
var _cam_pan: Vector2 = Vector2.ZERO
var _show_debug: bool = false
var _joint_nodes: Array = []
var _grid_node: MeshInstance3D
var _axes_node: Node3D

## Domain randomization
var _domain_randomizer: RefCounted = null
var _domain_randomize_enabled: bool = false
var _domain_randomize_interval: float = 0.5
var _domain_randomize_timer: float = 0.0


func _ready() -> void:
	_setup_camera()
	_setup_lighting()
	_setup_environment()
	_setup_grid()
	_setup_axes()
	_load_demo_robot()


func _setup_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.set_name("CameraPivot")
	add_child(_cam_pivot)

	_camera = Camera3D.new()
	_camera.set_name("Camera")
	_camera.fov = 60
	_cam_pivot.add_child(_camera)

	_update_camera_transform()


func _update_camera_transform() -> void:
	var rad_yaw = deg_to_rad(_cam_yaw)
	var rad_pitch = deg_to_rad(_cam_pitch)
	var x = _cam_distance * cos(rad_pitch) * sin(rad_yaw)
	var y = _cam_distance * sin(rad_pitch)
	var z = _cam_distance * cos(rad_pitch) * cos(rad_yaw)
	_cam_pivot.position = Vector3(_cam_pan.x, _cam_pan.y, 0.0)
	_camera.position = Vector3(x, y, z)
	if _camera.is_inside_tree():
		_camera.look_at(_cam_pivot.global_position, Vector3.UP)


func _setup_lighting() -> void:
	# Ambient light
	var ambient = DirectionalLight3D.new()
	ambient.set_name("AmbientLight")
	ambient.light_color = Color(0.5, 0.5, 0.6)
	ambient.light_energy = 0.4
	ambient.rotation_degrees = Vector3(-45, 30, 0)
	add_child(ambient)

	# Key light
	var key_light = DirectionalLight3D.new()
	key_light.set_name("KeyLight")
	key_light.light_color = Color(1.0, 0.98, 0.95)
	key_light.light_energy = 1.0
	key_light.rotation_degrees = Vector3(-45, -45, 0)
	key_light.shadow_enabled = true
	add_child(key_light)

	# Fill light
	var fill_light = DirectionalLight3D.new()
	fill_light.set_name("FillLight")
	fill_light.light_color = Color(0.7, 0.75, 0.9)
	fill_light.light_energy = 0.3
	fill_light.rotation_degrees = Vector3(-30, 120, 0)
	add_child(fill_light)


func _setup_environment() -> void:
	# Ground plane
	var ground = MeshInstance3D.new()
	ground.set_name("Ground")

	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(10, 10)
	ground.mesh = ground_mesh

	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.3, 0.3, 0.35)
	ground_mat.roughness = 0.9
	ground.material_override = ground_mat

	# Make ground receive shadows
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var ground_static = StaticBody3D.new()
	ground_static.set_name("GroundStatic")
	ground_static.add_child(ground)

	var ground_collision = CollisionShape3D.new()
	ground_collision.shape = WorldBoundaryShape3D.new()
	ground_static.add_child(ground_collision)

	add_child(ground_static)


func _setup_grid() -> void:
	_grid_node = MeshInstance3D.new()
	_grid_node.set_name("GridOverlay")
	var grid_mesh = ImmediateMesh.new()
	_grid_node.mesh = grid_mesh
	_grid_node.material_override = _make_grid_material()
	add_child(_grid_node)
	_draw_grid_lines(grid_mesh)


func _make_grid_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.4, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.flags_unshaded = true
	mat.flags_no_depth_test = true
	return mat


func _draw_grid_lines(mesh: ImmediateMesh) -> void:
	var grid_size = 20
	var step = 1.0
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-grid_size, grid_size + 1):
		var major = (i % 5 == 0)
		var color = Color(0.4, 0.4, 0.45, 0.5) if major else Color(0.3, 0.3, 0.35, 0.25)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(i * step, 0.001, -grid_size * step))
		mesh.surface_add_vertex(Vector3(i * step, 0.001, grid_size * step))
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(-grid_size * step, 0.001, i * step))
		mesh.surface_add_vertex(Vector3(grid_size * step, 0.001, i * step))
	mesh.surface_end()


func _setup_axes() -> void:
	_axes_node = Node3D.new()
	_axes_node.set_name("AxesIndicator")
	var axis_length = 0.5
	var axis_radius = 0.01
	_create_axis_cylinder(_axes_node, Vector3(axis_length / 2.0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 90), axis_length, axis_radius, Color.RED)
	_create_axis_cylinder(_axes_node, Vector3(0, axis_length / 2.0, 0), Vector3(0, 1, 0), Vector3.ZERO, axis_length, axis_radius, Color.GREEN)
	_create_axis_cylinder(_axes_node, Vector3(0, 0, axis_length / 2.0), Vector3(0, 0, 1), Vector3(90, 0, 0), axis_length, axis_radius, Color.BLUE)
	add_child(_axes_node)


func _create_axis_cylinder(parent: Node3D, pos: Vector3, _dir: Vector3, rot: Vector3, length: float, radius: float, col: Color) -> void:
	var cyl = MeshInstance3D.new()
	var cyl_mesh = CylinderMesh.new()
	cyl_mesh.height = length
	cyl_mesh.top_radius = radius
	cyl_mesh.bottom_radius = radius
	cyl.mesh = cyl_mesh
	cyl.position = pos
	cyl.rotation_degrees = rot
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.flags_unshaded = true
	cyl.material_override = mat
	parent.add_child(cyl)


# ===== Robot Loading =====

func _load_demo_robot() -> void:
	# Create a simple differential drive robot using Godot nodes
	_create_demo_robot("TurtleBot4")
	robot_loaded.emit(_robot_root)


func _create_demo_robot(name: String) -> void:
	if _robot_root and is_instance_valid(_robot_root):
		_robot_root.queue_free()

	_robot_root = Node3D.new()
	_robot_root.set_name(name)
	add_child(_robot_root)

	_joint_nodes.clear()

	# Create robot base
	var base = _create_link("base_link", BoxMesh.new(), Vector3(0.3, 0.1, 0.2), Color(0.2, 0.6, 0.2))
	base.position = Vector3(0, 0.05, 0)
	_robot_root.add_child(base)

	# Create wheel joints
	var left_wheel = _create_wheel("left_wheel", Vector3(-0.12, -0.01, 0.1))
	var right_wheel = _create_wheel("right_wheel", Vector3(-0.12, -0.01, -0.1))

	# Add wheels to base
	base.add_child(left_wheel.joint)
	base.add_child(right_wheel.joint)

	# Store wheel joints for control
	_joint_nodes.append(left_wheel.joint)
	_joint_nodes.append(right_wheel.joint)

	# Create sensor mount
	var sensor_mount = _create_sensor_mount()
	sensor_mount.position = Vector3(0.08, 0.08, 0)
	base.add_child(sensor_mount)

	print("RobotViewer: Created demo robot with ", _joint_nodes.size(), " controllable joints")


func _create_link(link_name: String, mesh: Mesh, size: Vector3, color: Color) -> Node3D:
	var node = Node3D.new()
	node.set_name(link_name)

	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.set_name("Visual")
	mesh_instance.mesh = mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	node.add_child(mesh_instance)

	var collision = CollisionShape3D.new()
	collision.set_name("Collision")
	if mesh is BoxMesh:
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
	node.add_child(collision)

	return node


func _create_wheel(wheel_name: String, position: Vector3) -> Dictionary:
	# Create a wheel using a CylinderShape
	var joint = Node3D.new()
	joint.set_name(wheel_name + "_joint")
	joint.position = position
	joint.set_meta("joint_type", "revolute")
	joint.set_meta("joint_axis", Vector3(0, 0, 1))

	var wheel = Node3D.new()
	wheel.set_name(wheel_name)
	wheel.rotation_degrees = Vector3(90, 0, 0)

	var wheel_mesh = CylinderMesh.new()
	wheel_mesh.top_radius = 0.04
	wheel_mesh.bottom_radius = 0.04
	wheel_mesh.height = 0.02

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.set_name("Visual")
	mesh_instance.mesh = wheel_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mesh_instance.material_override = mat
	wheel.add_child(mesh_instance)

	var collision = CollisionShape3D.new()
	collision.set_name("Collision")
	var cylinder = CylinderShape3D.new()
	cylinder.height = 0.02
	cylinder.radius = 0.04
	collision.shape = cylinder
	wheel.add_child(collision)

	joint.add_child(wheel)

	return {"joint": joint, "wheel": wheel, "position": position}


func _create_sensor_mount() -> Node3D:
	var mount = Node3D.new()
	mount.set_name("sensor_mount")

	var sensor_box = BoxMesh.new()
	sensor_box.size = Vector3(0.08, 0.05, 0.08)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.set_name("Visual")
	mesh_instance.mesh = sensor_box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.1)
	mesh_instance.material_override = mat
	mount.add_child(mesh_instance)

	return mount


# ===== Domain Randomization =====

func _process(delta: float) -> void:
	if not _domain_randomize_enabled or not _domain_randomizer:
		return
	_domain_randomize_timer += delta
	if _domain_randomize_timer >= _domain_randomize_interval:
		_domain_randomize_timer = 0.0
		_domain_randomize_all()


func enable_domain_randomization(enabled: bool) -> void:
	_domain_randomize_enabled = enabled
	if enabled:
		if not _domain_randomizer:
			var DomainRandomizer = load("res://scripts/sensors/domain_randomizer.gd")
			_domain_randomizer = DomainRandomizer.new()
			_domain_randomizer.setup(self, _camera, [])
		_domain_randomize_timer = _domain_randomize_interval


func set_randomization_interval(sec: float) -> void:
	_domain_randomize_interval = sec


func _domain_randomize_all() -> void:
	if _domain_randomizer:
		_domain_randomizer.randomize_all()


# ===== URDF Loading =====

func load_urdf(urdf_path: String) -> bool:
	if _robot_root and is_instance_valid(_robot_root):
		_robot_root.queue_free()

	_robot_root = URDFToGodot.parse(urdf_path)
	if not _robot_root:
		push_error("RobotViewer: Failed to load URDF: " + urdf_path)
		return false

	add_child(_robot_root)
	_collect_joints()
	robot_loaded.emit(_robot_root)
	print("RobotViewer: Loaded URDF: " + urdf_path)
	return true


func _collect_joints() -> void:
	_joint_nodes.clear()
	if not _robot_root:
		return

	# Collect joints by type/metadata (URDF joints carry "joint_type"; also match physics joint nodes).
	for node in _robot_root.find_children("*", "Node3D", true, false):
		if node.has_meta("joint_type") or node is PinJoint3D or node is SliderJoint3D:
			_joint_nodes.append(node)


# ===== Joint Control =====

func get_joint_count() -> int:
	return _joint_nodes.size()


func get_joint_name(index: int) -> String:
	if index < 0 or index >= _joint_nodes.size():
		return ""
	return _joint_nodes[index].name


func set_joint_rotation(index: int, angle_degrees: float) -> void:
	if index < 0 or index >= _joint_nodes.size():
		return
	var joint = _joint_nodes[index]
	var joint_type: String = joint.get_meta("joint_type", "revolute")
	var axis: Vector3 = joint.get_meta("joint_axis", Vector3(0, 1, 0))
	if joint_type == "prismatic":
		joint.position = axis * angle_degrees
	else:
		joint.rotation = axis * deg_to_rad(angle_degrees)
	joint_changed.emit(joint.name, angle_degrees)


func get_joint_rotation(index: int) -> float:
	if index < 0 or index >= _joint_nodes.size():
		return 0.0
	var joint = _joint_nodes[index]
	var axis: Vector3 = joint.get_meta("joint_axis", Vector3(0, 1, 0))
	return joint.rotation_degrees.dot(axis)


func get_joint_limits(index: int) -> Dictionary:
	if index < 0 or index >= _joint_nodes.size():
		return {}
	var joint = _joint_nodes[index]
	if joint.has_meta("has_limits") and joint.get_meta("has_limits"):
		return {
			"lower": joint.get_meta("limit_lower", -180.0),
			"upper": joint.get_meta("limit_upper", 180.0)
		}
	return {"lower": -180.0, "upper": 180.0}


func get_robot_root() -> Node3D:
	return _robot_root


# ===== Camera Controls =====

func set_camera_yaw(yaw_degrees: float) -> void:
	_cam_yaw = yaw_degrees
	_update_camera_transform()


func set_camera_pitch(pitch_degrees: float) -> void:
	_cam_pitch = clamp(pitch_degrees, -89.0, 89.0)
	_update_camera_transform()


func set_camera_distance(distance: float) -> void:
	_cam_distance = clamp(distance, 0.5, 20.0)
	_update_camera_transform()


func orbit_camera(delta_yaw: float, delta_pitch: float) -> void:
	_cam_yaw += delta_yaw
	_cam_pitch = clamp(_cam_pitch + delta_pitch, -89.0, 89.0)
	_update_camera_transform()


func pan_camera(delta_x: float, delta_y: float) -> void:
	var pan_speed = _cam_distance * 0.005
	_cam_pan.x += delta_x * pan_speed
	_cam_pan.y += delta_y * pan_speed
	_update_camera_transform()


# ===== Input Handling =====

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_camera_distance(_cam_distance - 0.3)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_camera_distance(_cam_distance + 0.3)
	elif event is InputEventMouseMotion:
		var motion = event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			if Input.is_key_pressed(KEY_SHIFT) or motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
				pan_camera(-motion.relative.x * 0.005, motion.relative.y * 0.005)
			else:
				orbit_camera(-motion.relative.x * 0.3, -motion.relative.y * 0.3)
		elif motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			pan_camera(-motion.relative.x * 0.005, motion.relative.y * 0.005)


# ===== Debug =====

func set_show_debug(show: bool) -> void:
	_show_debug = show
	# Flat unshaded "debug" look across the robot's meshes (wireframe-style debug view).
	if _robot_root == null:
		return
	var debug_mat: StandardMaterial3D = null
	if show:
		debug_mat = StandardMaterial3D.new()
		debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		debug_mat.albedo_color = Color(0.3, 0.6, 1.0)
	for mi in _robot_root.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = debug_mat


func set_grid_visible(visible: bool) -> void:
	if _grid_node:
		_grid_node.visible = visible


func reset_view() -> void:
	_cam_yaw = 0.0
	_cam_pitch = 30.0
	_cam_distance = 3.0
	_cam_pan = Vector2.ZERO
	_update_camera_transform()
