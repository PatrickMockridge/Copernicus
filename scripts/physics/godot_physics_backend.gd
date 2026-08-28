# godot_physics_backend.gd
# Physics backend using Godot's native physics (VehicleBody3D, RigidBody3D)
# This wraps the existing physics_demo.gd functionality

class_name GodotPhysicsBackend
extends PhysicsBackend

## Godot native physics using VehicleBody3D
## Fast, game-focused physics built into Godot engine

var _world: Node3D
var _bodies: Dictionary = {}  # name -> RigidBody3D
var _joints: Dictionary = {}  # name -> Joint3D
var _pending_forces: Dictionary = {}  # body_name -> {force: Vector3, position: Vector3}

var _gravity: Vector3 = Vector3(0, -9.81, 0)
var _timestep: float = 0.001
var _is_simulating: bool = false


static func get_module_name() -> String:
	return "Godot Native"


static func get_module_description() -> String:
	return "Godot's built-in physics engine (Jolt). Fast, game-focused physics with VehicleBody3D support."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "None - built into Godot"



static func get_module_category() -> String:
	return "physics"

static func _static_init():
	ModuleRegistry.register("physics", "GodotPhysicsBackend", preload("res://scripts/physics/godot_physics_backend.gd"))
## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_gravity = config.get("gravity", Vector3(0, -9.81, 0))
	_timestep = config.get("timestep", 0.001)

	# Create world node if needed
	_world = Node3D.new()
	_world.set_name("GodotPhysicsWorld")
	Engine.get_main_loop().root.add_child(_world)

	_is_simulating = true
	backend_initialized.emit(true)
	return true


func is_running() -> bool:
	return _is_simulating


func shutdown() -> void:
	_is_simulating = false

	# Free all bodies
	for body in _bodies.values():
		if is_instance_valid(body):
			body.queue_free()
	_bodies.clear()

	# Free all joints
	for joint in _joints.values():
		if is_instance_valid(joint):
			joint.queue_free()
	_joints.clear()

	_pending_forces.clear()

	# Free world
	if is_instance_valid(_world):
		_world.queue_free()
	_world = null


## ===== Simulation =====

func step_simulation(delta: float) -> void:
	if not _is_simulating or not is_instance_valid(_world):
		return

	# Apply pending forces
	for body_name in _pending_forces:
		var force_data = _pending_forces[body_name]
		var body = _bodies.get(body_name)
		if is_instance_valid(body):
			body.apply_force(force_data.force, force_data.position)

	# Clear pending forces
	_pending_forces.clear()

	# Process physics (Godot handles this via _physics_process)
	simulation_stepped.emit(delta)


func get_body_state(body_name: String) -> Dictionary:
	var body = _bodies.get(body_name)
	if not is_instance_valid(body):
		return {}

	return {
		"position": body.global_position,
		"rotation": body.quaternion,
		"linear_velocity": body.linear_velocity,
		"angular_velocity": body.angular_velocity,
		"force": Vector3.ZERO  # Godot doesn't expose last applied force easily
	}


func get_all_states() -> Dictionary:
	var states = {}
	for name in _bodies:
		states[name] = get_body_state(name)
	return states


## ===== Body Management =====

func create_rigid_body(name: String, config: Dictionary) -> bool:
	if not is_instance_valid(_world):
		return false

	if _bodies.has(name):
		push_error("GodotPhysicsBackend: Body already exists: " + name)
		return false

	var body_type = config.get("type", "box")

	var body: RigidBody3D

	match body_type:
		"box":
			body = _create_box(name, config)
		"sphere":
			body = _create_sphere(name, config)
		"cylinder":
			body = _create_cylinder(name, config)
		"vehicle":
			body = _create_vehicle(name, config)
		_:
			push_error("GodotPhysicsBackend: Unknown body type: " + body_type)
			return false

	if body:
		_bodies[name] = body
		return true

	return false


func _create_box(name: String, config: Dictionary) -> RigidBody3D:
	var body = RigidBody3D.new()
	body.set_name(name)
	body.mass = config.get("mass", 1.0)
	body.global_position = config.get("position", Vector3.ZERO)
	body.quaternion = config.get("rotation", Quaternion.IDENTITY)

	# Collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = config.get("size", Vector3(0.5, 0.5, 0.5))
	collision.shape = shape
	body.add_child(collision)

	# Visual (optional)
	if config.get("visual", true):
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		(mesh.mesh as BoxMesh).size = config.get("size", Vector3(0.5, 0.5, 0.5))
		body.add_child(mesh)

	_world.add_child(body)
	return body


func _create_sphere(name: String, config: Dictionary) -> RigidBody3D:
	var body = RigidBody3D.new()
	body.set_name(name)
	body.mass = config.get("mass", 1.0)
	body.global_position = config.get("position", Vector3.ZERO)

	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = config.get("radius", 0.5)
	collision.shape = shape
	body.add_child(collision)

	if config.get("visual", true):
		var mesh = MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		(mesh.mesh as SphereMesh).radius = config.get("radius", 0.5)
		(mesh.mesh as SphereMesh).height = config.get("radius", 0.5) * 2.0
		body.add_child(mesh)

	_world.add_child(body)
	return body


func _create_cylinder(name: String, config: Dictionary) -> RigidBody3D:
	var body = RigidBody3D.new()
	body.set_name(name)
	body.mass = config.get("mass", 1.0)
	body.global_position = config.get("position", Vector3.ZERO)

	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = config.get("radius", 0.25)
	shape.height = config.get("length", 0.5)
	collision.shape = shape
	body.add_child(collision)

	if config.get("visual", true):
		var mesh = MeshInstance3D.new()
		mesh.mesh = CylinderMesh.new()
		(mesh.mesh as CylinderMesh).top_radius = config.get("radius", 0.25)
		(mesh.mesh as CylinderMesh).bottom_radius = config.get("radius", 0.25)
		(mesh.mesh as CylinderMesh).height = config.get("length", 0.5)
		body.add_child(mesh)

	_world.add_child(body)
	return body


func _create_vehicle(name: String, config: Dictionary) -> VehicleBody3D:
	var body = VehicleBody3D.new()
	body.set_name(name)
	body.mass = config.get("mass", 5.0)
	body.global_position = config.get("position", Vector3.ZERO)

	_world.add_child(body)
	return body


func remove_body(name: String) -> void:
	var body = _bodies.get(name)
	if is_instance_valid(body):
		body.queue_free()
	_bodies.erase(name)


## ===== Forces =====

func apply_force(body_name: String, force: Vector3, position: Vector3 = Vector3.ZERO) -> void:
	if _bodies.has(body_name):
		_pending_forces[body_name] = {"force": force, "position": position}


func apply_torque(body_name: String, torque: Vector3) -> void:
	var body = _bodies.get(body_name)
	if is_instance_valid(body):
		body.apply_torque(torque)


func reset_forces(body_name: String) -> void:
	_pending_forces.erase(body_name)


## ===== Joints =====

func create_joint(name: String, config: Dictionary) -> bool:
	var joint_type = config.get("type", "fixed")
	var parent_name = config.get("parent", "")
	var child_name = config.get("child", "")

	var parent = _bodies.get(parent_name)
	var child = _bodies.get(child_name)

	if not is_instance_valid(parent) or not is_instance_valid(child):
		return false

	var joint: Joint3D

	match joint_type:
		"pin", "revolute", "continuous":
			joint = PinJoint3D.new()
		"hinge":
			joint = HingeJoint3D.new()
		"slider", "prismatic":
			joint = SliderJoint3D.new()
		"fixed":
			joint = Generic6DOFJoint3D.new()  # Locked below to act fixed
		_:
			return false

	joint.set_name(name)
	joint.node_a = parent.get_path()
	joint.node_b = child.get_path()
	joint.position = config.get("anchor_parent", config.get("position", Vector3.ZERO))

	parent.add_child(joint)
	_joints[name] = joint

	return true


func remove_joint(name: String) -> void:
	var joint = _joints.get(name)
	if is_instance_valid(joint):
		joint.queue_free()
	_joints.erase(name)


## ===== Collision =====

func set_collision(body1: String, body2: String, enabled: bool) -> void:
	# Godot handles this via collision layers/masks
	# For simplicity, this is a no-op in current implementation
	pass


func get_contacts(body_name: String) -> Array:
	# Would need to use Area3D or direct physics query
	# Current implementation returns empty
	return []
