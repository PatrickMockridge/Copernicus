# physics_demo.gd
# Basic physics demo using Godot's native VehicleBody3D
# Differential drive robot with keyboard/ROS2 cmd_vel control

class_name PhysicsDemo
extends Node3D

signal vehicle_spawned(vehicle: VehicleBody3D)

var _vehicle: VehicleBody3D
var _camera: Camera3D
var _cam_pivot: Node3D
var _front_left_wheel: VehicleWheel3D
var _front_right_wheel: VehicleWheel3D
var _rear_left_wheel: VehicleWheel3D
var _rear_right_wheel: VehicleWheel3D

var _linear_vel: float = 0.0
var _angular_vel: float = 0.0
var _max_linear_vel: float = 5.0
var _max_steering: float = 0.5
var _wheel_base: float = 0.3  # Distance between front and rear axles

var _use_keyboard: bool = true


func _ready() -> void:
	_setup_camera()
	_setup_lighting()
	_create_vehicle()
	_create_obstacles()


func _setup_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.set_name("CameraPivot")
	add_child(_cam_pivot)

	_camera = Camera3D.new()
	_camera.set_name("Camera")
	_camera.fov = 60
	_cam_pivot.add_child(_camera)


func _setup_lighting() -> void:
	var ambient = DirectionalLight3D.new()
	ambient.set_name("AmbientLight")
	ambient.light_color = Color(0.4, 0.4, 0.5)
	ambient.light_energy = 0.3
	ambient.rotation_degrees = Vector3(-45, 30, 0)
	add_child(ambient)

	var key_light = DirectionalLight3D.new()
	key_light.set_name("KeyLight")
	key_light.light_color = Color(1.0, 0.98, 0.95)
	key_light.light_energy = 0.8
	key_light.rotation_degrees = Vector3(-45, -45, 0)
	key_light.shadow_enabled = true
	add_child(key_light)


func _create_vehicle() -> void:
	# Create vehicle body
	_vehicle = VehicleBody3D.new()
	_vehicle.set_name("TurtleBot")
	_vehicle.mass = 5.0
	add_child(_vehicle)

	# Create vehicle body collision
	var body_collision = CollisionShape3D.new()
	body_collision.set_name("BodyCollision")
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.3, 0.1, 0.2)
	body_collision.shape = box_shape
	_vehicle.add_child(body_collision)

	# Create body visual
	var body_mesh = MeshInstance3D.new()
	body_mesh.set_name("BodyVisual")
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.1, 0.2)
	body_mesh.mesh = box_mesh
	body_mesh.position.y = 0.05
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.6, 0.2)
	body_mesh.material_override = body_mat
	_vehicle.add_child(body_mesh)

	# Create wheels
	_front_left_wheel = _create_wheel("FrontLeftWheel", Vector3(-0.12, 0, 0.1))
	_front_right_wheel = _create_wheel("FrontRightWheel", Vector3(-0.12, 0, -0.1))
	_rear_left_wheel = _create_wheel("RearLeftWheel", Vector3(0.12, 0, 0.1))
	_rear_right_wheel = _create_wheel("RearRightWheel", Vector3(0.12, 0, -0.1))

	_front_left_wheel.spring_length = 0.1
	_front_right_wheel.spring_length = 0.1
	_rear_left_wheel.spring_length = 0.1
	_rear_right_wheel.spring_length = 0.1

	_vehicle.add_child(_front_left_wheel)
	_vehicle.add_child(_front_right_wheel)
	_vehicle.add_child(_rear_left_wheel)
	_vehicle.add_child(_rear_right_wheel)

	# Position vehicle
	_vehicle.position = Vector3(0, 0.2, 0)

	vehicle_spawned.emit(_vehicle)
	print("PhysicsDemo: Created vehicle with wheels")


func _create_wheel(wheel_name: String, position: Vector3) -> VehicleWheel3D:
	var wheel = VehicleWheel3D.new()
	wheel.set_name(wheel_name)
	wheel.position = position

	# Wheel mesh
	var wheel_mesh = CylinderMesh.new()
	wheel_mesh.top_radius = 0.04
	wheel_mesh.bottom_radius = 0.04
	wheel_mesh.height = 0.02

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.set_name("WheelMesh")
	mesh_instance.mesh = wheel_mesh
	mesh_instance.rotation_degrees = Vector3(90, 0, 0)
	wheel.add_child(mesh_instance)

	# Wheel collision
	var wheel_collision = CollisionShape3D.new()
	wheel_collision.set_name("WheelCollision")
	var cylinder = CylinderShape3D.new()
	cylinder.height = 0.02
	cylinder.radius = 0.04
	wheel_collision.shape = cylinder
	wheel.add_child(wheel_collision)

	# Material
	var wheel_mat = StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.1, 0.1, 0.1)
	mesh_instance.material_override = wheel_mat

	return wheel


func _create_obstacles() -> void:
	# Ground plane
	var ground = StaticBody3D.new()
	ground.set_name("Ground")
	var ground_collision = CollisionShape3D.new()
	ground_collision.shape = PlaneShape3D.new()
	ground.add_child(ground_collision)

	var ground_mesh = MeshInstance3D.new()
	ground_mesh.set_name("GroundMesh")
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	ground_mesh.mesh = plane_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.3, 0.3, 0.35)
	ground_mat.roughness = 0.9
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)

	add_child(ground)

	# Create some obstacles
	_create_obstacle_box(Vector3(2, 0.2, 0), Vector3(0.3, 0.4, 0.3), Color(0.7, 0.2, 0.2))
	_create_obstacle_box(Vector3(3, 0.15, 1), Vector3(0.4, 0.3, 0.4), Color(0.2, 0.5, 0.7))
	_create_obstacle_box(Vector3(1.5, 0.1, -1.5), Vector3(0.5, 0.2, 0.5), Color(0.7, 0.5, 0.2))


func _create_obstacle_box(position: Vector3, size: Vector3, color: Color) -> void:
	var obstacle = StaticBody3D.new()
	obstacle.set_name("Obstacle")
	obstacle.position = position

	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	(collision.shape as BoxShape3D).size = size
	obstacle.add_child(collision)

	var mesh = MeshInstance3D.new()
	mesh.set_name("ObstacleMesh")
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	mesh.material_override = StandardMaterial3D.new()
	(mesh.material_override as StandardMaterial3D).albedo_color = color
	obstacle.add_child(mesh)

	add_child(obstacle)


# ===== Control =====

func _physics_process(delta: float) -> void:
	if not _vehicle:
		return

	# Update camera to follow vehicle
	_update_camera()

	if _use_keyboard:
		_handle_keyboard_input(delta)
	else:
		_apply_differential_drive(delta)


func _handle_keyboard_input(delta: float) -> void:
	var forward = Input.is_action_pressed("ui_up")
	var backward = Input.is_action_pressed("ui_down")
	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")

	_linear_vel = 0.0
	_angular_vel = 0.0

	if forward:
		_linear_vel = _max_linear_vel
	elif backward:
		_linear_vel = -_max_linear_vel * 0.5

	if left:
		_angular_vel = _max_steering
	elif right:
		_angular_vel = -_max_steering

	_apply_differential_drive(delta)


func _apply_differential_drive(delta: float) -> void:
	# Differential drive kinematics
	# v_left = v_linear - omega * wheel_base / 2
	# v_right = v_linear + omega * wheel_base / 2
	var half_wheel_base = 0.1  # Distance from center to each wheel
	var left_vel = _linear_vel - _angular_vel * half_wheel_base
	var right_vel = _linear_vel + _angular_vel * half_wheel_base

	# Convert to wheel rpm (simplified)
	var wheel_radius = 0.04
	var left_rpm = (left_vel / (2.0 * PI * wheel_radius)) * 60.0
	var right_rpm = (right_vel / (2.0 * PI * wheel_radius)) * 60.0

	# Apply to wheels
	_front_left_wheel.engine_force = left_rpm * 0.1
	_front_right_wheel.engine_force = right_rpm * 0.1
	_rear_left_wheel.engine_force = left_rpm * 0.1
	_rear_right_wheel.engine_force = right_rpm * 0.1

	# Steering for front wheels
	_front_left_wheel.steering = _angular_vel
	_front_right_wheel.steering = _angular_vel


func _update_camera() -> void:
	if _cam_pivot and _vehicle:
		var target = _vehicle.position
		var offset = Vector3(0, 1.5, 2.5)
		_cam_pivot.position = target - offset
		_cam_pivot.look_at(target + Vector3(0, 0.5, 0), Vector3.UP)


# ===== ROS2 cmd_vel Interface =====

func apply_cmd_vel(linear: float, angular: float) -> void:
	_linear_vel = clamp(linear, -_max_linear_vel, _max_linear_vel)
	_angular_vel = clamp(angular, -_max_steering, _max_steering)
	_use_keyboard = false


# ===== Getters =====

func get_vehicle() -> VehicleBody3D:
	return _vehicle


func get_wheel_count() -> int:
	return 4


func get_wheel_name(index: int) -> String:
	match index:
		0: return "FrontLeft"
		1: return "FrontRight"
		2: return "RearLeft"
		3: return "RearRight"
	return ""
