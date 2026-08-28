# turtle_controller.gd
# Reusable turtlebot controller for navigation demos
# Supports native VehicleBody3D control and ROS2 cmd_vel interface

class_name TurtleController
extends Node3D

signal position_updated(position: Vector3)
signal navigation_started()
signal navigation_finished()

## Control modes
enum Mode { NATIVE, ROS2 }

## Configuration
var _wheel_radius: float = 0.04
var _wheel_separation: float = 0.2
var _max_linear_vel: float = 2.0
var _max_angular_vel: float = 2.0

## State
var _mode: Mode = Mode.NATIVE
var _vehicle: VehicleBody3D
var _current_path: Array = []
var _path_index: int = 0
var _target_position: Vector3 = Vector3.INF
var _is_navigating: bool = false
var _nav_speed: float = 1.0  # meters per second

## Path following
var _waypoint_threshold: float = 0.1  # meters to consider waypoint reached
var _turn_threshold: float = 0.2  # radians to consider rotation done


func _ready() -> void:
	_setup_vehicle()


func _setup_vehicle() -> void:
	_vehicle = VehicleBody3D.new()
	_vehicle.set_name("TurtleBot")
	_vehicle.mass = 3.0
	_vehicle.linear_damp = 2.0
	_vehicle.angular_damp = 3.0
	add_child(_vehicle)

	# Body collision
	var body_collision = CollisionShape3D.new()
	body_collision.set_name("BodyCollision")
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.2, 0.08, 0.15)
	body_collision.shape = box_shape
	_vehicle.add_child(body_collision)

	# Body visual - green turtle shell style
	var body_mesh = MeshInstance3D.new()
	body_mesh.set_name("BodyVisual")
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.2, 0.08, 0.15)
	body_mesh.mesh = box_mesh
	body_mesh.position.y = 0.04
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.7, 0.3)
	body_mat.roughness = 0.6
	body_mesh.material_override = body_mat
	_vehicle.add_child(body_mesh)

	# Create 4 wheels
	var fl = _create_wheel("FrontLeft", Vector3(-0.07, 0, 0.06))
	var fr = _create_wheel("FrontRight", Vector3(-0.07, 0, -0.06))
	var rl = _create_wheel("RearLeft", Vector3(0.07, 0, 0.06))
	var rr = _create_wheel("RearRight", Vector3(0.07, 0, -0.06))
	_vehicle.add_child(fl)
	_vehicle.add_child(fr)
	_vehicle.add_child(rl)
	_vehicle.add_child(rr)

	# Position at origin
	_vehicle.position = Vector3(0, _wheel_radius, 0)


func _create_wheel(name: String, position: Vector3) -> VehicleWheel3D:
	var wheel = VehicleWheel3D.new()
	wheel.set_name(name)
	wheel.position = position
	wheel.spring_length = 0.05
	wheel.wheel_radius = _wheel_radius

	# Wheel mesh (cylinder rotated 90 degrees)
	var wheel_mesh = MeshInstance3D.new()
	wheel_mesh.set_name("Mesh")
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = _wheel_radius
	cylinder.bottom_radius = _wheel_radius
	cylinder.height = 0.015
	wheel_mesh.mesh = cylinder
	wheel_mesh.rotation_degrees = Vector3(90, 0, 0)
	wheel.add_child(wheel_mesh)

	# Wheel collision
	var wheel_collision = CollisionShape3D.new()
	wheel_collision.set_name("Collision")
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.height = 0.015
	cylinder_shape.radius = _wheel_radius
	wheel_collision.shape = cylinder_shape
	wheel.add_child(wheel_collision)

	# Wheel material
	var wheel_mat = StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.1, 0.1, 0.1)
	wheel_mesh.material_override = wheel_mat

	return wheel


func _physics_process(delta: float) -> void:
	if _mode == Mode.NATIVE and _is_navigating and not _current_path.is_empty():
		_follow_path(delta)


func _follow_path(delta: float) -> void:
	if _path_index >= _current_path.size():
		_is_navigating = false
		navigation_finished.emit()
		return

	var target = _current_path[_path_index]
	var current_pos = _vehicle.position

	# Check if close enough to waypoint
	var dist = current_pos.distance_to(target)
	if dist < _waypoint_threshold:
		_path_index += 1
		if _path_index >= _current_path.size():
			_is_navigating = false
			navigation_finished.emit()
		return

	# Calculate desired heading
	var direction = (target - current_pos).normalized()
	var desired_angle = atan2(direction.x, direction.z)
	var current_angle = _vehicle.rotation.y

	# Normalize angle difference
	var angle_diff = desired_angle - current_angle
	while angle_diff > PI:
		angle_diff -= 2 * PI
	while angle_diff < -PI:
		angle_diff += 2 * PI

	# Rotate towards target
	var turn_speed = 3.0 * delta
	if abs(angle_diff) > _turn_threshold:
		_vehicle.rotation.y += sign(angle_diff) * min(abs(angle_diff), turn_speed)
		_apply_wheel_velocities(0, 0.5)
	else:
		# Move towards target
		var move_speed = min(_nav_speed, dist / delta)
		_apply_wheel_velocities(move_speed, 0)

	position_updated.emit(_vehicle.position)


func _apply_wheel_velocities(linear: float, angular: float) -> void:
	var half_base = _wheel_separation / 2.0
	var left_vel = linear - angular * half_base
	var right_vel = linear + angular * half_base

	# Convert to engine force (simplified)
	_front_left_wheel().engine_force = left_vel * 10
	_front_right_wheel().engine_force = right_vel * 10
	_rear_left_wheel().engine_force = left_vel * 10
	_rear_right_wheel().engine_force = right_vel * 10

	# Steering
	_front_left_wheel().steering = angular * 0.5
	_front_right_wheel().steering = angular * 0.5


func _front_left_wheel() -> VehicleWheel3D:
	return _vehicle.get_node("FrontLeft") as VehicleWheel3D


func _front_right_wheel() -> VehicleWheel3D:
	return _vehicle.get_node("FrontRight") as VehicleWheel3D


func _rear_left_wheel() -> VehicleWheel3D:
	return _vehicle.get_node("RearLeft") as VehicleWheel3D


func _rear_right_wheel() -> VehicleWheel3D:
	return _vehicle.get_node("RearRight") as VehicleWheel3D


## ===== Public API =====

func set_mode(mode: Mode) -> void:
	_mode = mode


func get_mode() -> Mode:
	return _mode


func navigate_along_path(path: Array) -> void:
	if path.is_empty():
		return
	_current_path = path
	_path_index = 0
	_is_navigating = true
	navigation_started.emit()


func navigate_to(position: Vector3) -> void:
	_target_position = position


func set_nav_speed(speed: float) -> void:
	_nav_speed = speed


func stop_navigation() -> void:
	_is_navigating = false
	_current_path.clear()
	_apply_wheel_velocities(0, 0)


func get_vehicle_position() -> Vector3:
	if _vehicle:
		return _vehicle.position
	return Vector3.ZERO


func get_vehicle_yaw() -> float:
	if _vehicle:
		return _vehicle.rotation.y
	return 0.0


func set_vehicle_position(pos: Vector3) -> void:
	if _vehicle:
		_vehicle.position = pos


func set_vehicle_yaw(angle: float) -> void:
	if _vehicle:
		_vehicle.rotation.y = angle


func get_vehicle_body() -> VehicleBody3D:
	return _vehicle


func is_navigating() -> bool:
	return _is_navigating


## ===== ROS2 cmd_vel Interface =====

func apply_cmd_vel(linear: float, angular: float) -> void:
	_use_keyboard = false
	_linear_vel = clamp(linear, -_max_linear_vel, _max_linear_vel)
	_angular_vel = clamp(angular, -_max_angular_vel, _max_angular_vel)
	_apply_wheel_velocities(_linear_vel, _angular_vel)


var _linear_vel: float = 0.0
var _angular_vel: float = 0.0
var _use_keyboard: bool = true


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
		_angular_vel = _max_angular_vel
	elif right:
		_angular_vel = -_max_angular_vel

	_apply_wheel_velocities(_linear_vel, _angular_vel)
