# nav2_bridge.gd
# ROS2 Nav2 bridge for industry-standard navigation
# Connects to Nav2 via ROS2 services for path planning

class_name Nav2Bridge
extends NavPlanner

## ROS2 connection
var _ros_bridge: Node
var _process_path: String = "nav2_bridge.py"

## Current map
var _map_topic: String = "/map"
var _map_received: bool = false

## Last path
var _planned_path: Array = []

## Configuration
var _planner_id: String = "GridBased"
var _use_astar: bool = false


static func get_module_name() -> String:
	return "Nav2 (ROS2)"


static func get_module_description() -> String:
	return "Industry-standard navigation via ROS2 Nav2. Provides SLAM, path planning, and localization."


static func is_available() -> bool:
	return Nav2Bridge._check_ros2_available()


static func _check_ros2_available() -> bool:
	var output = []; var result = OS.execute("ros2", ["pkg", "list"], output, true)
	return result == 0


static func get_requirements() -> String:
	return "ROS2 + Nav2 packages installed. Run: sudo apt install ros-{DISTRO}-navigation2 ros-{DISTRO}-nav2-bringup"



static func get_module_category() -> String:
	return "nav"

static func _static_init():
	ModuleRegistry.register("nav", "Nav2Bridge", preload("res://scripts/nav/nav2_bridge.gd"))
func initialize(config: Dictionary) -> bool:
	super.initialize(config)
	_planner_id = config.get("planner_id", "GridBased")
	_use_astar = config.get("use_astar", false)
	return true


## ===== Map Handling =====

func set_map(map_data: Dictionary) -> void:
	_map_topic = map_data.get("map_topic", "/map")
	planner_error.emit("Nav2 uses live SLAM maps. Set map_topic and ensure Nav2 is running.")


func clear_map() -> void:
	_map_received = false
	_planned_path.clear()


## ===== Path Planning =====

func plan(start: Vector3, goal: Vector3) -> Array:
	if not is_available():
		push_error("Nav2Bridge: ROS2 not available")
		planner_error.emit("ROS2 not installed or not sourced")
		return []

	planning_started.emit()

	# Send request to nav2_bridge.py
	var request = {
		"cmd": "plan",
		"start": [start.x, start.y, start.z],
		"goal": [goal.x, goal.y, goal.z],
		"planner_id": _planner_id,
		"use_astar": _use_astar
	}

	var response = _send_request(request)

	if response.get("status") == "ok" and response.get("cmd") == "plan":
		var path_data = response.get("path", [])
		_planned_path = _parse_path(path_data)
		planning_finished.emit(true, _planned_path)
		return _planned_path
	else:
		var error_msg = response.get("message", "Unknown error")
		push_error("Nav2Bridge: Planning failed - " + error_msg)
		planner_error.emit(error_msg)
		planning_finished.emit(false, [])
		return []


func _parse_path(path_data: Array) -> Array:
	var path: Array = []
	for pos in path_data:
		if pos is Array and pos.size() >= 3:
			path.append(Vector3(pos[0], pos[1], pos[2]))
	return path


## ===== Robot Localization =====

func set_robot_pose(pose: Transform3D) -> void:
	var request = {
		"cmd": "localize",
		"position": [pose.origin.x, pose.origin.y, pose.origin.z],
		"rotation": [pose.basis.get_euler().x, pose.basis.get_euler().y, pose.basis.get_euler().z]
	}
	_send_request(request)


## ===== Lifecycle =====

func start_navigation() -> void:
	var request = {"cmd": "start"}
	_send_request(request)


func stop_navigation() -> void:
	var request = {"cmd": "stop"}
	_send_request(request)


func clear_costmap() -> void:
	var request = {"cmd": "clear_costmap"}
	_send_request(request)


## ===== Communication =====

func _send_request(request: Dictionary) -> Dictionary:
	# Use temp file IPC pattern (same as PyBullet)
	var temp_dir = "/tmp/copernicus_nav2_%d" % OS.get_process_id()
	var cmd_file = temp_dir + "/cmd.json"
	var resp_file = temp_dir + "/resp.json"

	# Create temp directory
	OS.execute("mkdir", ["-p", temp_dir], [], true)

	# Write command to temp file
	var f = FileAccess.open(cmd_file, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(request))
		f.close()
	else:
		return {"status": "error", "message": "Failed to write command"}

	# Execute Python bridge to process command
	var script_path = ProjectSettings.globalize_path("res://scripts/nav/nav2_bridge.py")
	var escaped_cmd = cmd_file.replace("\\", "\\\\").replace("'", "\\'")
	var escaped_script = script_path.replace("\\", "\\\\").replace("'", "\\'")

	var output = []
	var result = OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

# Import the bridge module
import importlib.util
spec = importlib.util.spec_from_file_location('nav2_bridge', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# Read command
with open('%s', 'r') as f:
    cmd = json.load(f)

# Create bridge and process command
bridge = module.Nav2BridgeStandalone()
bridge.process_command(cmd)

# Write response
with open('%s', 'w') as f:
    json.dump(bridge._last_response, f)
""" % [escaped_script, escaped_script, escaped_cmd, resp_file.replace("\\", "\\\\").replace("'", "\\'")]], output, true)

	# Read response from temp file
	f = FileAccess.open(resp_file, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			return parsed

	# Clean up
	OS.execute("rm", ["-rf", temp_dir], [], true)

	return {"status": "error", "message": "No response from nav2_bridge"}


## ===== Static Helpers =====

static func check_navigation_stack() -> Dictionary:
	var status = {
		"nav2_available": false,
		"planner_available": false,
		"controller_available": false,
		"amcl_available": false
	}

	var output = []
	var result = OS.execute("ros2", ["pkg", "list"], output, true)
	if result == 0 and output.size() > 0:
		# Join all lines — package names are spread across the whole listing.
		var output_str := ""
		for line in output:
			output_str += str(line) + "\n"
		status.nav2_available = "navigation2" in output_str
		status.planner_available = "nav2_bringup" in output_str
		status.amcl_available = "nav2_amcl" in output_str

	return status
