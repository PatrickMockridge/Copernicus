# moveit_ik_bridge.gd
# Bridge to MoveIt IK solver via ROS2
# Uses a persistent Python subprocess (scripts/ik/moveit_bridge.py) over TCP.

class_name MoveItIKBridge
extends IKSolver

## MoveIt configuration
var _robot_description: String = "robot_description"
var _group_name: String = "manipulator"
var _timeout: float = 0.5  # seconds

## Python bridge process
var _bridge: PythonBridge
var _port: int = 9880

## Internal state
var _joint_rotations: Array = []
var _end_effector_position: Vector3 = Vector3.ZERO
var _final_distance: float = INF
var _iterations_used: int = 1


static func get_module_name() -> String:
	return "MoveIt IK"


static func get_module_description() -> String:
	return "Industry-grade IK via ROS2/MoveIt. Requires ROS2 and MoveIt configured."


static func is_available() -> bool:
	# Check if ros2 CLI is available
	var output = []
	var ret = OS.execute("ros2", ["pkg", "list"], output, false)
	return ret == 0


static func get_requirements() -> String:
	return "Requires: ROS2 + MoveIt configured with robot_description"



static func get_module_category() -> String:
	return "ik"

static func _static_init():
	ModuleRegistry.register("ik", "MoveItIKBridge", preload("res://scripts/ik/moveit_ik_bridge.gd"))
func initialize(config: Dictionary) -> bool:
	super.initialize(config)
	_robot_description = config.get("robot_description", "robot_description")
	_group_name = config.get("group_name", "manipulator")
	_timeout = config.get("timeout", 0.5)
	_port = config.get("port", 9880)

	# Start the Python bridge (ROS2/MoveIt). Fail loudly if it can't start.
	var start_result = _start_bridge()
	if start_result.is_err():
		solver_error.emit(start_result.get_error())
		return false

	return true


func shutdown() -> void:
	if _bridge:
		_bridge.shutdown()
		_bridge = null


func solve(chain: Array, target: Vector3) -> bool:
	if chain.is_empty():
		return false

	reset()
	solving_started.emit()

	# Build IK request
	var request = {
		"cmd": "solve_ik",
		"group": _group_name,
		"robot_description": _robot_description,
		"target_position": [target.x, target.y, target.z],
		"timeout": _timeout
	}

	# Send request
	var response = _send_command(request)

	if response.get("status") != "ok":
		solver_error.emit(response.get("message", "IK solve failed"))
		solving_finished.emit(false, 0)
		return false

	# Extract solution
	var solution = response.get("solution", {})
	var joint_positions = solution.get("joint_positions", [])

	# Convert joint positions to rotations
	_joint_rotations.clear()
	for i in range(min(joint_positions.size(), chain.size())):
		# MoveIt returns positions, we convert to quaternions
		var angle = joint_positions[i]
		var axis = chain[i].get("axis", Vector3.UP)
		_joint_rotations.append(Quaternion(axis, angle))

	_final_distance = response.get("distance", 0.0)
	_iterations_used = 1
	_end_effector_position = target

	solving_finished.emit(true, _iterations_used)
	return true


func get_joint_rotations() -> Array:
	return _joint_rotations.duplicate()


func get_end_effector_position() -> Vector3:
	return _end_effector_position


func get_final_distance() -> float:
	return _final_distance


func get_iterations_used() -> int:
	return _iterations_used


func reset() -> void:
	_joint_rotations.clear()
	_end_effector_position = Vector3.ZERO
	_final_distance = INF
	_iterations_used = 0


## ===== Bridge Communication =====

func _start_bridge() -> Result:
	var script_path = ProjectSettings.globalize_path("res://scripts/ik/moveit_bridge.py")
	_bridge = PythonBridge.new()
	var ok := _bridge.start(script_path, _port, ["--robot-description", _robot_description, "--group", _group_name])
	if not ok:
		_bridge = null
		return Result.err("Failed to start MoveIt bridge (ROS2/MoveIt not available?)")
	return Result.ok({})


func _send_command(cmd: Dictionary) -> Dictionary:
	if not _bridge or not _bridge.is_bridge_connected():
		return {"status": "error", "message": "MoveIt bridge not connected"}
	return _bridge.send(cmd)
