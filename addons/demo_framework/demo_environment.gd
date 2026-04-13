# demo_environment.gd
# Reusable demo environment: camera, lighting, ground, obstacles
# Use this to avoid duplicating infrastructure code across demos

class_name DemoEnvironment
extends Node3D

## Camera
var _camera: Camera3D
var _cam_pivot: Node3D
var _cam_distance: float = 5.0
var _cam_height: float = 3.0
var _cam_angle: float = -30.0  # degrees

## Lights
var _key_light: DirectionalLight3D
var _ambient_light: DirectionalLight3D

## Ground
var _ground: StaticBody3D

## Obstacles container
var _obstacles: Node3D


func _init() -> void:
	_obstacles = Node3D.new()
	_obstacles.set_name("Obstacles")
	add_child(_obstacles)


## ===== Camera =====

func setup_camera(distance: float = 5.0, height: float = 3.0, angle: float = -30.0) -> void:
	_cam_distance = distance
	_cam_height = height
	_cam_angle = angle

	_cam_pivot = Node3D.new()
	_cam_pivot.set_name("CameraPivot")
	add_child(_cam_pivot)

	_camera = Camera3D.new()
	_camera.set_name("MainCamera")
	_camera.fov = 60
	_cam_pivot.add_child(_camera)

	_update_camera_position()


func _update_camera_position() -> void:
	if _cam_pivot:
		var rad = deg_to_rad(_cam_angle)
		var x = _cam_distance * cos(rad)
		var y = _cam_height
		var z = _cam_distance * sin(rad)
		_cam_pivot.position = Vector3(x, y, z)


func look_at_target(target: Vector3) -> void:
	if _camera and _cam_pivot:
		_cam_pivot.look_at(target, Vector3.UP)


func get_camera() -> Camera3D:
	return _camera


func orbit_camera(delta_x: float, delta_y: float) -> void:
	_cam_angle += delta_x * 0.5
	_cam_distance = clamp(_cam_distance - delta_y * 0.1, 2.0, 15.0)
	_update_camera_position()


## ===== Lighting =====

func setup_lighting() -> void:
	_ambient_light = DirectionalLight3D.new()
	_ambient_light.set_name("AmbientLight")
	_ambient_light.light_color = Color(0.4, 0.4, 0.5)
	_ambient_light.light_energy = 0.4
	_ambient_light.rotation_degrees = Vector3(-45, 30, 0)
	_ambient_light.shadow_enabled = false
	add_child(_ambient_light)

	_key_light = DirectionalLight3D.new()
	_key_light.set_name("KeyLight")
	_key_light.light_color = Color(1.0, 0.98, 0.95)
	_key_light.light_energy = 0.9
	_key_light.rotation_degrees = Vector3(-45, -45, 0)
	_key_light.shadow_enabled = true
	add_child(_key_light)


## ===== Ground =====

func setup_ground(size: Vector2 = Vector2(12, 12), color: Color = Color(0.25, 0.28, 0.32)) -> void:
	_ground = StaticBody3D.new()
	_ground.set_name("Ground")
	add_child(_ground)

	var collision = CollisionShape3D.new()
	collision.shape = WorldBoundaryShape3D.new()
	_ground.add_child(collision)

	var mesh = MeshInstance3D.new()
	mesh.set_name("GroundMesh")
	mesh.mesh = PlaneMesh.new()
	mesh.mesh.size = size
	mesh.position.y = -0.001  # Slightly below origin to avoid z-fighting
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material_override = mat
	_ground.add_child(mesh)


## ===== Obstacles =====

func create_box(pos: Vector3, size: Vector3, color: Color = Color(0.6, 0.6, 0.6)) -> void:
	var box = StaticBody3D.new()
	box.set_name("Obstacle")
	box.position = pos

	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = size
	box.add_child(collision)

	var mesh = MeshInstance3D.new()
	mesh.set_name("Mesh")
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_override.albedo_color = color
	box.add_child(mesh)

	_obstacles.add_child(box)


func create_wall(pos: Vector3, size: Vector3, color: Color = Color(0.5, 0.5, 0.55)) -> void:
	create_box(pos, size, color)


func create_default_obstacles() -> void:
	# Boundary walls
	create_wall(Vector3(0, 0.15, -5.5), Vector3(10, 0.3, 0.1))
	create_wall(Vector3(0, 0.15, 5.5), Vector3(10, 0.3, 0.1))
	create_wall(Vector3(-5.5, 0.15, 0), Vector3(0.1, 0.3, 10))
	create_wall(Vector3(5.5, 0.15, 0), Vector3(0.1, 0.3, 10))

	# Interior obstacles
	create_box(Vector3(2, 0.15, 2), Vector3(0.6, 0.3, 0.6), Color(0.8, 0.3, 0.3))
	create_box(Vector3(-2, 0.1, -1.5), Vector3(0.5, 0.2, 0.5), Color(0.3, 0.6, 0.8))
	create_box(Vector3(1, 0.12, -3), Vector3(0.4, 0.24, 0.4), Color(0.7, 0.6, 0.2))
	create_box(Vector3(-3, 0.1, 2.5), Vector3(0.5, 0.2, 0.5), Color(0.5, 0.4, 0.7))


## ===== Create Default Environment =====

func create_default_environment(ground_size: Vector2 = Vector2(12, 12)) -> void:
	setup_camera()
	setup_lighting()
	setup_ground(ground_size)
	create_default_obstacles()
	print("DemoEnvironment: Created default environment")


## ===== Complete Setup Helper =====

static func create_full_environment(parent: Node, ground_size: Vector2 = Vector2(12, 12)) -> DemoEnvironment:
	var env = DemoEnvironment.new()
	parent.add_child(env)
	env.create_default_environment(ground_size)
	return env
