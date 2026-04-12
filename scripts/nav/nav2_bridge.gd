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


static func get_planner_name() -> String:
	return "Nav2 (ROS2)"


static func get_planner_description() -> String:
	return "Industry-standard navigation via ROS2 Nav2. Provides SLAM, path planning, and localization."


static func is_available() -> bool:
	return Nav2Bridge._check_ros2_available()


static func _check_ros2_available() -> bool:
	var result = OS.execute("ros2", ["pkg", "list"], true)
	return result[0] == 0


static func get_requirements() -> String:
	return "ROS2 + Nav2 packages installed. Run: sudo apt install ros-{DISTRO}-navigation2 ros-{DISTRO}-nav2-bringup"


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
	var json_str = JSON.stringify(request)

	# Try to find running nav2_bridge process
	var args = ["service", "call", "/nav2_bridge/request", "std_srvs/srv/Empty", "{data: '" + json_str + "'}"]

	var output = []
	var _result = OS.execute("ros2", args, output, true, true)

	# Parse output - expected JSON response
	if output.size() > 0:
		var output_str = output[0]
		# Extract JSON from output
		var json_match = output_str.strip_edges()
		if json_match.begins_with("{"):
			var json_result = JSON.parse_string(output_str)
			if json_result is Dictionary:
				return json_result

	return {"status": "error", "message": "No response from nav2_bridge"}


## ===== Static Helpers =====

static func check_navigation_stack() -> Dictionary:
	var status = {
		"nav2_available": false,
		"planner_available": false,
		"controller_available": false,
		"amcl_available": false
	}

	var result = OS.execute("ros2", ["pkg", "list"], true)
	if result[0] == 0:
		var output = result[1]
		status.nav2_available = "navigation2" in output
		status.planner_available = "nav2_bringup" in output
		status.amcl_available = "nav2_amcl" in output

	return status
