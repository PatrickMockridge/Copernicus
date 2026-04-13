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
var _cam_pitch: float = -30.0
var _show_debug: bool = false
var _joint_nodes: Array = []  # Track joint nodes for slider control


func _ready() -> void:
	_setup_camera()
	_setup_lighting()
	_setup_environment()
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
	_camera.position = Vector3(x, y, z)
	_cam_pivot.look_at(Vector3.ZERO, Vector3.UP)


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
	var left_wheel = _create_wheel("left_wheel", Vector3(-0.12, 0, 0.1))
	var right_wheel = _create_wheel("right_wheel", Vector3(-0.12, 0, -0.1))

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

	# Find all nodes that look like joints
	for node in _robot_root.get_children():
		if node.name.ends_with("_joint") or node.name.contains("wheel"):
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
	joint.rotation_degrees.y = angle_degrees
	joint_changed.emit(joint.name, angle_degrees)


func get_joint_rotation(index: int) -> float:
	if index < 0 or index >= _joint_nodes.size():
		return 0.0
	return _joint_nodes[index].rotation_degrees.y


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


# ===== Input Handling =====

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			# Orbit camera on right mouse drag
			pass
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_camera_distance(_cam_distance - 0.3)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_camera_distance(_cam_distance + 0.3)
	elif event is InputEventMouseMotion:
		var motion = event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			orbit_camera(-motion.relative_x * 0.3, -motion.relative_y * 0.3)


# ===== Debug =====

func set_show_debug(show: bool) -> void:
	_show_debug = show
	# Toggle collision wireframe or similar
