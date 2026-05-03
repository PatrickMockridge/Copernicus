# ik_solver.gd
# Abstract interface for IK solvers
# All IK solvers (CCD, FABRIK, MoveIt) must implement this

class_name IKSolver
extends CopernicusModule

## Signals

signal solving_started()
signal solving_progress(iterations: int, distance: float)
signal solving_finished(success: bool, iterations: int)
signal solver_error(message: String)


## ===== Configuration =====

## Maximum iterations for iterative solvers
var _max_iterations: int = 10
## Tolerance in meters - solver stops when closer than this
var _tolerance: float = 0.001
## Allow rotation on X axis
var _allow_rotation_x: bool = true
## Allow rotation on Y axis
var _allow_rotation_y: bool = true
## Allow rotation on Z axis
var _allow_rotation_z: bool = true


## ===== Core Methods =====

## Initialize the solver with optional configuration
func initialize(config: Dictionary) -> bool:
	_max_iterations = config.get("max_iterations", 10)
	_tolerance = config.get("tolerance", 0.001)
	_allow_rotation_x = config.get("allow_rotation_x", true)
	_allow_rotation_y = config.get("allow_rotation_y", true)
	_allow_rotation_z = config.get("allow_rotation_z", true)
	return true


## Solve IK for a chain of joints
## chain = Array of JointData, each containing:
##   {
##     "node": Node3D,           # The joint node
##     "position": Vector3,       # Joint position in world space
##     "rotation": Quaternion,    # Current rotation
##     "axis": Vector3,          # Rotation axis (local)
##     "min_angle": float,       # Min angle limit (optional)
##     "max_angle": float,       # Max angle limit (optional)
##   }
## target = desired end effector position in world space
## Returns true if solution found within tolerance
func solve(chain: Array, target: Vector3) -> bool:
	push_error("IKSolver.solve() must be implemented by subclass")
	return false


## Get the solved joint rotations after solve()
## Returns Array of Quaternion, one per joint in chain
func get_joint_rotations() -> Array:
	push_error("IKSolver.get_joint_rotations() must be implemented by subclass")
	return []


## Get end effector position after solve (may differ from target if failed)
func get_end_effector_position() -> Vector3:
	push_error("IKSolver.get_end_effector_position() must be implemented by subclass")
	return Vector3.ZERO


## Get distance from end effector to target after solve
func get_final_distance() -> float:
	push_error("IKSolver.get_final_distance() must be implemented by subclass")
	return INF


## Get number of iterations used in last solve
func get_iterations_used() -> int:
	return 0


## Reset solver state (call before new solve)
func reset() -> void:
	pass


## ===== Configuration Setters =====

func set_max_iterations(iterations: int) -> void:
	_max_iterations = max(1, iterations)


func set_tolerance(tolerance: float) -> void:
	_tolerance = max(0.0, tolerance)


func set_rotation_constraints(allow_x: bool, allow_y: bool, allow_z: bool) -> void:
	_allow_rotation_x = allow_x
	_allow_rotation_y = allow_y
	_allow_rotation_z = allow_z



	## ===== Module Identity =====

	static func get_module_category() -> String:
		return "ik"

	static func get_solver_name() -> String:
		return get_module_name()

	static func get_solver_description() -> String:
		return get_module_description()





## Check if this solver is available (dependencies installed, etc)
static func is_available() -> bool:
	return false


## Get requirements for this solver (for error messages)
static func get_requirements() -> String:
	return ""


## ===== Joint Data Helper =====

## Helper to create joint data from a Node3D
static func create_joint_data(
	node: Node3D,
	axis: Vector3 = Vector3(0, 1, 0),
	min_angle: float = -PI,
	max_angle: float = PI
) -> Dictionary:
	return {
		"node": node,
		"position": node.global_position,
		"rotation": node.quaternion,
		"axis": axis.normalized(),
		"min_angle": min_angle,
		"max_angle": max_angle
	}


## Helper to apply solved rotations back to nodes
static func apply_rotations(chain: Array, rotations: Array) -> void:
	for i in range(min(chain.size(), rotations.size())):
		if chain[i].has("node") and is_instance_valid(chain[i]["node"]):
			chain[i]["node"].quaternion = rotations[i]


## Calculate forward kinematics for a chain
## Returns end effector position
static func forward_kinematics(chain: Array) -> Vector3:
	if chain.is_empty():
		return Vector3.ZERO

	var position = Vector3.ZERO
	var rotation = Quaternion.IDENTITY

	for joint_data in chain:
		if joint_data.has("position"):
			position = joint_data["position"]
		if joint_data.has("rotation"):
			rotation = joint_data["rotation"]

	return position


## Calculate distance from end effector to target
static func calculate_distance(chain: Array, target: Vector3) -> float:
	var end_pos = forward_kinematics(chain)
	return end_pos.distance_to(target)
