# turtle_demo.gd
# Simplified TurtleBot demo - no complex dependencies
# Click on ground to move robot directly toward target

class_name TurtleDemo
extends Node3D

## Robot state
var _robot: CharacterBody3D
var _robot_mesh: MeshInstance3D
var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _move_speed: float = 2.0

## Camera
var _camera: Camera3D
var _cam_pivot: Node3D

## UI
var _instructions: Label

## Click detection
var _ground_plane: StaticBody3D


func _ready() -> void:
	_setup_environment()
	_setup_robot()
	_setup_ui()
	print("TurtleDemo: Click on ground to move robot!")


func _setup_environment() -> void:
	# Camera
	_cam_pivot = Node3D.new()
	_cam_pivot.set_name("CameraPivot")
	add_child(_cam_pivot)

	_camera = Camera3D.new()
	_camera.set_name("MainCamera")
	_camera.fov = 60
	_cam_pivot.add_child(_camera)
	_cam_pivot.position = Vector3(0, 5, 5)
	_camera.look_at(Vector3.ZERO)

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

	# Ground
	var ground = StaticBody3D.new()
	ground.set_name("Ground")

	var ground_collision = CollisionShape3D.new()
	ground_collision.shape = WorldBoundaryShape3D.new()
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
	_ground_plane = ground

	# Simple obstacles
	_create_box(Vector3(2, 0.15, 2), Vector3(0.6, 0.3, 0.6), Color(0.8, 0.3, 0.3))
	_create_box(Vector3(-2, 0.1, -1.5), Vector3(0.5, 0.2, 0.5), Color(0.3, 0.6, 0.8))
	_create_box(Vector3(1, 0.12, -3), Vector3(0.4, 0.24, 0.4), Color(0.7, 0.6, 0.2))
	_create_box(Vector3(-3, 0.1, 2.5), Vector3(0.5, 0.2, 0.5), Color(0.5, 0.4, 0.7))


func _create_box(pos: Vector3, size: Vector3, color: Color) -> void:
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
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	box.add_child(mesh)

	add_child(box)


func _setup_robot() -> void:
	_robot = CharacterBody3D.new()
	_robot.set_name("TurtleBot")
	_robot.position = Vector3(0, 0.05, 0)
	_robot.max_slides = 4
	_robot.floor_stop_on_slope = true

	# Robot body (cylinder for differential drive look)
	var body = CylinderShape3D.new()
	body.height = 0.08
	body.radius = 0.12

	var body_collision = CollisionShape3D.new()
	body_collision.shape = body
	_robot.add_child(body_collision)

	_robot_mesh = MeshInstance3D.new()
	_robot_mesh.set_name("RobotMesh")
	var cylinder = CylinderMesh.new()
	cylinder.height = 0.08
	cylinder.top_radius = 0.12
	cylinder.bottom_radius = 0.12
	_robot_mesh.mesh = cylinder
	var robot_mat = StandardMaterial3D.new()
	robot_mat.albedo_color = Color(0.2, 0.8, 0.3)
	_robot_mesh.material_override = robot_mat
	_robot.add_child(_robot_mesh)

	# Wheels (small boxes on sides)
	for x_offset in [-0.1, 0.1]:
		var wheel = MeshInstance3D.new()
		wheel.set_name("Wheel")
		var wheel_mesh = BoxMesh.new()
		wheel_mesh.size = Vector3(0.04, 0.08, 0.04)
		wheel.mesh = wheel_mesh
		wheel.material_override = StandardMaterial3D.new()
		wheel.position = Vector3(x_offset, -0.02, 0)
		_robot.add_child(wheel)

	add_child(_robot)
	_target_position = _robot.position


func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.set_name("UI")
	add_child(canvas)

	var label = Label.new()
	label.set_name("Instructions")
	label.text = "Click on ground to move robot"
	label.position = Vector2(10, 10)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	canvas.add_child(label)
	_instructions = label


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)


func _handle_click(screen_pos: Vector2) -> void:
	var from = _camera.project_ray_origin(screen_pos)
	var to = from + _camera.project_ray_normal(screen_pos) * 100

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)

	# Only hit the ground plane
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if result:
		_target_position = result.position
		_target_position.y = _robot.position.y
		_is_moving = true
		print("TurtleDemo: Moving to ", _target_position)


func _physics_process(delta: float) -> void:
	if _is_moving:
		var direction = (_target_position - _robot.position)
		direction.y = 0
		var distance = direction.length()

		if distance < 0.05:
			_is_moving = false
			_robot.velocity = Vector3.ZERO
		else:
			direction = direction.normalized()
			_robot.velocity = direction * _move_speed

			# Rotate robot to face direction
			var target_angle = atan2(direction.x, direction.z)
			_robot.rotation.y = lerp_angle(_robot.rotation.y, target_angle, delta * 8)

			_robot.move_and_slide()