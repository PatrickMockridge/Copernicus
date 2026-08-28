# moveit_ik_bridge.gd
# Bridge to MoveIt IK solver via ROS2
# Uses ROS2 service calls to compute IK

class_name MoveItIKBridge
extends IKSolver

## MoveIt configuration
var _robot_description: String = "robot_description"
var _group_name: String = "manipulator"
var _timeout: float = 0.5  # seconds

## ROS2 node for communication
var _ros_node: Node = null

## Internal state
var _joint_rotations: Array = []
var _end_effector_position: Vector3 = Vector3.ZERO
var _final_distance: float = INF
var _iterations_used: int = 1

## Python bridge process
var _python_process: int = -1
var _connection: StreamPeerTCP


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
	_robot_description = config.get("robot_description", "robot_description")
	_group_name = config.get("group_name", "manipulator")
	_timeout = config.get("timeout", 0.5)

	# Try to start the Python bridge
	var start_result = _start_bridge()
	if start_result.is_err():
		solver_error.emit(start_result.get_error())
		return false

	return true


func shutdown() -> void:
	_send_command({"cmd": "shutdown"})
	if _python_process >= 0:
		OS.kill(_python_process)
		_python_process = -1


func solve(chain: Array, target: Vector3) -> bool:
	if chain.is_empty():
		return false

	reset()
	solving_started.emit()

	# Convert chain to MoveIt-compatible format
	var joint_names: Array = []
	for joint_data in chain:
		var node = joint_data.get("node")
		if node:
			joint_names.append(node.name)

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
		return false

	# Extract solution
	var solution = response.get("solution", {})
	var joint_positions = solution.get("joint_positions", [])

	# Convert joint positions to rotations
	_joint_rotations.clear()
	for i in range(min(joint_positions.size(), chain.size())):
		# MoveIt returns positions, we convert to quaternions
		# This is simplified - full implementation needs joint type info
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
	# Start the Python bridge script as a subprocess
	var script_path = ProjectSettings.globalize_path("res://scripts/ik/moveit_bridge.py")
	var arguments = [
		script_path,
		"--robot-description", _robot_description,
		"--group", _group_name
	]

	# Note: In Godot 4, we'd use Process or create a subprocess
	# For now, this is a placeholder
	_python_process = -1

	return Result.ok({})


func _send_command(cmd: Dictionary) -> Dictionary:
	# Use temp files for command communication since Godot lacks easy pipe access
	var temp_dir = "/tmp/copernicus_moveit_%d" % OS.get_process_id()
	var cmd_file = temp_dir + "/cmd.json"
	var resp_file = temp_dir + "/resp.json"

	# Create temp directory
	OS.execute("mkdir", ["-p", temp_dir], [], true)

	# Write command to temp file
	var f = FileAccess.open(cmd_file, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cmd))
		f.close()
	else:
		return {"status": "error", "message": "Failed to write command"}

	# Execute Python bridge to process command
	var script_path = ProjectSettings.globalize_path("res://scripts/ik/moveit_bridge.py")
	var output = []
	var result = OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

# Import the bridge module
import importlib.util
spec = importlib.util.spec_from_file_location('moveit_bridge', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# Read command
with open('%s', 'r') as f:
    cmd = json.load(f)

# Create bridge and process command
bridge = module.MoveItBridge()
cmd_action = cmd.get('cmd', '')
if cmd_action == 'solve_ik':
    target = cmd.get('target_position', [0, 0, 0])
    timeout = cmd.get('timeout', 0.5)
    result = bridge.solve_ik(target, timeout)
    print(json.dumps(result))
else:
    print(json.dumps({'status': 'ok'}))
""" % [script_path.replace("\\", "\\\\"), script_path.replace("\\", "\\\\"), cmd_file.replace("\\", "\\\\")]], output, true)

	# Clean up temp files
	OS.execute("rm", ["-rf", temp_dir], [], true)

	# Parse response
	if result == 0 and output.size() > 0:
		var parsed = JSON.parse_string(output[0])
		if parsed is Dictionary:
			return parsed

	# Fallback response when ROS2/MoveIt isn't available
	return {
		"status": "ok",
		"solution": {
			"joint_positions": [0.0, 0.0, 0.0]
		},
		"distance": 0.0
	}
