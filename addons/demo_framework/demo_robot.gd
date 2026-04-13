# demo_robot.gd
# Reusable robot builder: creates CharacterBody3D with differential drive visuals
# Use with DemoEnvironment to build complete demo scenes

class_name DemoRobot
extends CharacterBody3D

## Visual components
var _body_mesh: MeshInstance3D
var _wheels: Array = []


## ===== Factory Methods =====

static func create_differential_drive(
	parent: Node,
	pos: Vector3 = Vector3.ZERO,
	body_color: Color = Color(0.2, 0.6, 0.2),
	wheel_color: Color = Color(0.15, 0.15, 0.15)
) -> DemoRobot:
	var robot = DemoRobot.new()
	parent.add_child(robot)
	robot.position = pos
	robot._create_body_differential(body_color)
	robot._create_wheels(wheel_color)
	return robot


## ===== Body =====

func _create_body_differential(color: Color) -> void:
	# Body collision (flat cylinder)
	var body_collision = CollisionShape3D.new()
	body_collision.shape = CylinderShape3D.new()
	body_collision.shape.height = 0.08
	body_collision.shape.radius = 0.12
	add_child(body_collision)

	# Body visual
	_body_mesh = MeshInstance3D.new()
	_body_mesh.set_name("BodyMesh")
	var cylinder = CylinderMesh.new()
	cylinder.height = 0.08
	cylinder.top_radius = 0.12
	cylinder.bottom_radius = 0.12
	_body_mesh.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	_body_mesh.material_override = mat
	add_child(_body_mesh)

	# Front sensor (small box for direction indicator)
	var sensor = MeshInstance3D.new()
	sensor.set_name("Sensor")
	sensor.mesh = BoxMesh.new()
	sensor.mesh.size = Vector3(0.1, 0.06, 0.04)
	sensor.position = Vector3(0, 0.02, -0.1)
	sensor.material_override = StandardMaterial3D.new()
	sensor.material_override.albedo_color = Color(0.8, 0.2, 0.2)
	add_child(sensor)


func _create_wheels(wheel_color: Color) -> void:
	for x_offset in [-0.1, 0.1]:
		var wheel = MeshInstance3D.new()
		wheel.set_name("Wheel")
		var wheel_mesh = BoxMesh.new()
		wheel_mesh.size = Vector3(0.03, 0.08, 0.06)
		wheel.mesh = wheel_mesh
		wheel.material_override = StandardMaterial3D.new()
		wheel.material_override.albedo_color = wheel_color
		wheel.position = Vector3(x_offset, -0.02, 0)
		add_child(wheel)
		_wheels.append(wheel)


## ===== Body Color =====

func set_body_color(color: Color) -> void:
	if _body_mesh and _body_mesh.material_override:
		_body_mesh.material_override.albedo_color = color


## ===== Create Simple Box Robot =====

static func create_box_robot(
	parent: Node,
	pos: Vector3 = Vector3.ZERO,
	size: Vector3 = Vector3(0.4, 0.15, 0.3),
	color: Color = Color(0.2, 0.6, 0.2)
) -> DemoRobot:
	var robot = DemoRobot.new()
	parent.add_child(robot)
	robot.position = pos

	# Body collision
	var body_coll = CollisionShape3D.new()
	body_coll.shape = BoxShape3D.new()
	body_coll.shape.size = size
	robot.add_child(body_coll)

	# Body visual
	var body_mesh = MeshInstance3D.new()
	body_mesh.set_name("BodyMesh")
	body_mesh.mesh = BoxMesh.new()
	body_mesh.mesh.size = size
	body_mesh.material_override = StandardMaterial3D.new()
	body_mesh.material_override.albedo_color = color
	robot.add_child(body_mesh)
	robot._body_mesh = body_mesh

	return robot
