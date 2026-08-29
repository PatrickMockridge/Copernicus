# physics_demo.gd
# Simplified physics demo - demonstrates Godot physics without complex vehicle dynamics
# WASD controls with CharacterBody3D + move_and_slide

class_name PhysicsDemo
extends Node3D

## Robot
var _robot: CharacterBody3D
var _linear_vel: float = 0.0
var _angular_vel: float = 0.0
var _move_speed: float = 5.0
var _turn_speed: float = 3.0

## Camera
var _camera: Camera3D
var _cam_pivot: Node3D
var _cam_distance: float = 3.0
var _cam_height: float = 2.0

## Controls state
var _w_pressed: bool = false
var _s_pressed: bool = false
var _a_pressed: bool = false
var _d_pressed: bool = false

## Scenario producer: marks "robot_moved" once the robot actually drives.
var _moved_marked: bool = false


func _ready() -> void:
	_setup_camera()
	_setup_lighting()
	_setup_robot()
	_setup_obstacles()
	print("PhysicsDemo: WASD to move, mouse to rotate camera")


func _setup_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.set_name("CameraPivot")
	add_child(_cam_pivot)

	_camera = Camera3D.new()
	_camera.set_name("MainCamera")
	_camera.fov = 60
	_cam_pivot.add_child(_camera)


func _update_camera() -> void:
	_cam_pivot.position = _robot.position + Vector3(0, _cam_height, _cam_distance)
	_cam_pivot.look_at(_robot.position)


func _setup_lighting() -> void:
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


func _setup_robot() -> void:
	_robot = CharacterBody3D.new()
	_robot.set_name("Robot")
	_robot.position = Vector3(0, 0.1, 0)
	_robot.max_slides = 4

	# Body collision
	var body_coll = CollisionShape3D.new()
	body_coll.shape = BoxShape3D.new()
	body_coll.shape.size = Vector3(0.4, 0.15, 0.3)
	_robot.add_child(body_coll)

	# Body visual
	var body_mesh = MeshInstance3D.new()
	body_mesh.set_name("BodyMesh")
	body_mesh.mesh = BoxMesh.new()
	body_mesh.mesh.size = Vector3(0.4, 0.15, 0.3)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.6, 0.2)
	body_mesh.material_override = body_mat
	_robot.add_child(body_mesh)

	# Front sensor (small box)
	var sensor = MeshInstance3D.new()
	sensor.set_name("Sensor")
	sensor.mesh = BoxMesh.new()
	sensor.mesh.size = Vector3(0.1, 0.08, 0.05)
	sensor.position = Vector3(0, 0, -0.18)
	sensor.material_override = StandardMaterial3D.new()
	sensor.material_override.albedo_color = Color(0.8, 0.2, 0.2)
	_robot.add_child(sensor)

	add_child(_robot)


func _setup_obstacles() -> void:
	# Ground
	var ground = StaticBody3D.new()
	ground.set_name("Ground")

	var ground_coll = CollisionShape3D.new()
	ground_coll.shape = WorldBoundaryShape3D.new()
	ground.add_child(ground_coll)

	var ground_mesh = MeshInstance3D.new()
	ground_mesh.set_name("GroundMesh")
	ground_mesh.mesh = PlaneMesh.new()
	ground_mesh.mesh.size = Vector2(20, 20)
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.28, 0.32)
	ground_mat.roughness = 0.9
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	add_child(ground)

	# Obstacles
	_create_box(Vector3(2, 0.2, 2), Vector3(0.5, 0.4, 0.5), Color(0.8, 0.3, 0.3))
	_create_box(Vector3(-2, 0.15, -1), Vector3(0.4, 0.3, 0.4), Color(0.3, 0.6, 0.8))
	_create_box(Vector3(1, 0.2, -3), Vector3(0.6, 0.4, 0.6), Color(0.7, 0.6, 0.2))
	_create_box(Vector3(-3, 0.15, 2), Vector3(0.5, 0.3, 0.5), Color(0.5, 0.4, 0.7))
	_create_box(Vector3(0, 0.3, 4), Vector3(1.5, 0.6, 0.3), Color(0.4, 0.5, 0.6))


func _create_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var box = StaticBody3D.new()
	box.set_name("Obstacle")
	box.position = pos

	var coll = CollisionShape3D.new()
	coll.shape = BoxShape3D.new()
	coll.shape.size = size
	box.add_child(coll)

	var mesh = MeshInstance3D.new()
	mesh.set_name("Mesh")
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_override.albedo_color = color
	box.add_child(mesh)

	add_child(box)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		match event.keycode:
			KEY_W:
				_w_pressed = event.pressed
			KEY_S:
				_s_pressed = event.pressed
			KEY_A:
				_a_pressed = event.pressed
			KEY_D:
				_d_pressed = event.pressed


func _physics_process(delta: float) -> void:
	# Movement
	var move_dir = Vector3.ZERO
	if _w_pressed:
		move_dir.z -= 1
	if _s_pressed:
		move_dir.z += 1
	if _a_pressed:
		_robot.rotation.y += _turn_speed * delta
	if _d_pressed:
		_robot.rotation.y -= _turn_speed * delta

	# Apply movement in robot's local space
	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()
		var world_dir = Vector3(
			move_dir.x * cos(_robot.rotation.y) - move_dir.z * sin(_robot.rotation.y),
			0,
			move_dir.x * sin(_robot.rotation.y) + move_dir.z * cos(_robot.rotation.y)
		)
		_robot.velocity = world_dir * _move_speed
		_mark_moved()
	else:
		_robot.velocity = Vector3.ZERO

	_robot.move_and_slide()
	_update_camera()


func _mark_moved() -> void:
	if _moved_marked:
		return
	_moved_marked = true
	var svc = get_node_or_null("/root/ScenarioService")
	if svc:
		svc.context["robot_moved"] = true
		svc.reevaluate()
