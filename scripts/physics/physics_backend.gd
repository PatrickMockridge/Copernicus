# physics_backend.gd
# Abstract interface for physics backends
# All physics backends (Godot native, PyBullet, Gazebo) must implement this

class_name PhysicsBackend
extends CopernicusModule

## Signals

signal body_moved(body_name: String, position: Vector3, rotation: Quaternion)
signal simulation_stepped(delta: float)
signal backend_initialized(success: bool)
signal backend_error(message: String)


## ===== Core Methods =====

## Initialize the physics backend
## config = {
##   "gravity": Vector3,
##   "timestep": float,
##   "substeps": int (optional)
## }
func initialize(config: Dictionary) -> bool:
	push_error("PhysicsBackend.initialize() must be implemented by subclass")
	return false


## Step the simulation forward
func step_simulation(delta: float) -> void:
	push_error("PhysicsBackend.step_simulation() must be implemented by subclass")


## Get the state of a specific body
## Returns: {
##   "position": Vector3,
##   "rotation": Quaternion,
##   "linear_velocity": Vector3,
##   "angular_velocity": Vector3,
##   "force": Vector3 (applied force last step)
## }
func get_body_state(body_name: String) -> Dictionary:
	push_error("PhysicsBackend.get_body_state() must be implemented by subclass")
	return {}


## Get states of all bodies
## Returns: { "body_name": state_dict, ... }
func get_all_states() -> Dictionary:
	push_error("PhysicsBackend.get_all_states() must be implemented by subclass")
	return {}


## Check if backend is running
func is_running() -> bool:
	push_error("PhysicsBackend.is_running() must be implemented by subclass")
	return false


## Shutdown the backend
func shutdown() -> void:
	push_error("PhysicsBackend.shutdown() must be implemented by subclass")


## ===== Body Management =====

## Create a rigid body
## config = {
##   "name": String,
##   "type": "box" | "sphere" | "cylinder" | "mesh",
##   "position": Vector3,
##   "rotation": Quaternion,
##   "mass": float,
##   "friction": float (optional),
##   "restitution": float (optional),
##   "size": Vector3 (for box),
##   "radius": float (for sphere/cylinder),
##   "length": float (for cylinder)
## }
func create_rigid_body(name: String, config: Dictionary) -> bool:
	push_error("PhysicsBackend.create_rigid_body() must be implemented by subclass")
	return false


## Remove a body
func remove_body(name: String) -> void:
	push_error("PhysicsBackend.remove_body() must be implemented by subclass")


## ===== Forces =====

## Apply a force to a body at a world position
func apply_force(body_name: String, force: Vector3, position: Vector3 = Vector3.ZERO) -> void:
	push_error("PhysicsBackend.apply_force() must be implemented by subclass")


## Apply torque (angular force) to a body
func apply_torque(body_name: String, torque: Vector3) -> void:
	push_error("PhysicsBackend.apply_torque() must be implemented by subclass")


## Reset all forces on a body
func reset_forces(body_name: String) -> void:
	push_error("PhysicsBackend.reset_forces() must be implemented by subclass")


## ===== Joint Management =====

## Create a joint between two bodies
## config = {
##   "name": String,
##   "type": "revolute" | "prismatic" | "fixed" | "spherical",
##   "parent": String (body name),
##   "child": String (body name),
##   "anchor_parent": Vector3,
##   "anchor_child": Vector3,
##   "axis": Vector3 (for revolute/prismatic),
##   "limits": { "lower": float, "upper": float } (optional)
## }
func create_joint(name: String, config: Dictionary) -> bool:
	push_error("PhysicsBackend.create_joint() must be implemented by subclass")
	return false


## Remove a joint
func remove_joint(name: String) -> void:
	push_error("PhysicsBackend.remove_joint() must be implemented by subclass")


## ===== Collision =====

## Enable/disable collision between two bodies
func set_collision(body1: String, body2: String, enabled: bool) -> void:
	push_error("PhysicsBackend.set_collision() must be implemented by subclass")


## Get all contact points for a body
func get_contacts(body_name: String) -> Array:
	push_error("PhysicsBackend.get_contacts() must be implemented by subclass")
	return []



	## ===== Module Identity =====

	static func get_module_category() -> String:
		return "physics"

	static func get_backend_name() -> String:
		return get_module_name()

	static func get_backend_description() -> String:
		return get_module_description()





## Check if this backend is available (dependencies installed, etc)
static func is_available() -> bool:
	return false


## Get requirements for this backend (for error messages)
static func get_requirements() -> String:
	return ""
