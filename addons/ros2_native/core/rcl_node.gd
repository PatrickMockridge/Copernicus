# rcl_node.gd
# rclpy wrapper for Godot - provides native ROS2 node functionality
# Uses Python subprocess for rclpy communication (same pattern as PyBullet)

class_name RclNode
extends RefCounted


## ===== Signals =====

signal publisher_added(topic: String, msg_type: String)
signal subscriber_added(topic: String, msg_type: String)
signal service_added(service: String, srv_type: String)
signal action_added(action: String, action_type: String)
signal node_error(error: String)


## ===== Configuration =====

var _node_name: String = "godot_rcl_node"
var _initialized: bool = false


## ===== Publishers/Subscribers =====

var _publishers: Dictionary = {}  # topic -> {msg_type, python_handle}
var _subscribers: Dictionary = {}  # topic -> {msg_type, callback, python_handle}
var _services: Dictionary = {}  # service -> {srv_type, python_handle}
var _action_clients: Dictionary = {}  # action -> {action_type, python_handle}
var _action_servers: Dictionary = {}


## ===== Static Methods =====

static func is_rclpy_available() -> bool:
	var result = OS.execute("python3", ["-c", "import rclpy; print('available')"], [], true)
	return result[0] == OK


static func get_requirements() -> String:
	return "Requires: ROS2 installed and sourced, rclpy Python package"


## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_node_name = config.get("node_name", "godot_rcl_node")

	# Start the Python node
	var result = _start_python_node()
	if result.is_err():
		node_error.emit(result.get_error())
		return false

	_initialized = true
	return true


func shutdown() -> void:
	_send_command({"cmd": "shutdown"})
	_initialized = false
	_publishers.clear()
	_subscribers.clear()
	_services.clear()


## ===== Publishers =====

## Create a publisher
func create_publisher(topic: String, msg_type: String, qos: int = 10) -> bool:
	var result = _send_command({
		"cmd": "create_publisher",
		"topic": topic,
		"msg_type": msg_type,
		"qos": qos
	})

	if result.get("status") == "ok":
		_publishers[topic] = {"msg_type": msg_type, "qos": qos}
		publisher_added.emit(topic, msg_type)
		return true

	return false


## Publish a message
func publish(topic: String, message: Dictionary) -> void:
	_send_command({
		"cmd": "publish",
		"topic": topic,
		"message": message
	})


## ===== Subscribers =====

## Create a subscriber
func create_subscription(topic: String, msg_type: String, callback: Callable, qos: int = 10) -> bool:
	var result = _send_command({
		"cmd": "create_subscription",
		"topic": topic,
		"msg_type": msg_type,
		"qos": qos
	})

	if result.get("status") == "ok":
		_subscribers[topic] = {"msg_type": msg_type, "callback": callback}
		subscriber_added.emit(topic, msg_type)
		return true

	return false


## ===== Services =====

## Create a service server
func create_service(service: String, srv_type: String, callback: Callable) -> bool:
	var result = _send_command({
		"cmd": "create_service",
		"service": service,
		"srv_type": srv_type
	})

	if result.get("status") == "ok":
		_services[service] = {"srv_type": srv_type, "callback": callback}
		service_added.emit(service, srv_type)
		return true

	return false


## Call a service client
func call_service(service: String, request: Dictionary) -> Dictionary:
	return _send_command({
		"cmd": "call_service",
		"service": service,
		"request": request
	})


## ===== Actions =====

## Create action client
func create_action_client(action: String, action_type: String) -> bool:
	var result = _send_command({
		"cmd": "create_action_client",
		"action": action,
		"action_type": action_type
	})

	if result.get("status") == "ok":
		_action_clients[action] = {"action_type": action_type}
		action_added.emit(action, action_type)
		return true

	return false


## Send action goal
func send_action_goal(action: String, goal: Dictionary) -> Dictionary:
	return _send_command({
		"cmd": "send_action_goal",
		"action": action,
		"goal": goal
	})


## ===== Parameters =====

## Set a parameter
func set_parameter(name: String, value: Variant) -> bool:
	var result = _send_command({
		"cmd": "set_parameter",
		"name": name,
		"value": _variant_to_py(value)
	})
	return result.get("status") == "ok"


## Get a parameter
func get_parameter(name: String) -> Variant:
	var result = _send_command({
		"cmd": "get_parameter",
		"name": name
	})
	return result.get("value", null)


## ===== Time =====

## Get current ROS time
func get_ros_time() -> float:
	var result = _send_command({"cmd": "get_time"})
	return result.get("time", 0.0)


## ===== Python Bridge =====

func _start_python_node() -> Result:
	var script_path = ProjectSettings.globalize_path("res://addons/ros2_native/core/rcl_node_script.py")
	var temp_dir = "/tmp/copernicus_rcl_%d" % OS.get_process_id()
	var cmd_file = temp_dir + "/cmd.json"
	var resp_file = temp_dir + "/resp.json"

	OS.execute("mkdir", ["-p", temp_dir], true)

	# Write initialization command
	var f = FileAccess.open(cmd_file, FileAccess.WRITE)
	if f == null:
		return Result.err("Failed to create temp dir")
	f.store_string(JSON.stringify({"cmd": "init", "node_name": _node_name}))
	f.close()

	# Execute Python node
	var output = []
	var result = OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('rcl_node_script', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# Read init command
with open('%s', 'r') as f:
    cmd = json.load(f)

# Create node
node = module.RclNodeScript()
node.process_command(cmd)

# Write response
with open('%s', 'w') as f:
    json.dump(node._last_response, f)
""" % (script_path.replace("\\", "\\\\"), script_path.replace("\\", "\\\\"), cmd_file.replace("\\", "\\\\"), resp_file.replace("\\", "\\\\"))], output, true)

	# Read response
	f = FileAccess.open(resp_file, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary and parsed.get("status") == "ok":
			return Result.ok({})
		return Result.err(parsed.get("message", "Unknown error"))

	return Result.err("No response from Python node")


func _send_command(cmd: Dictionary) -> Dictionary:
	var temp_dir = "/tmp/copernicus_rcl_%d" % OS.get_process_id()
	var cmd_file = temp_dir + "/cmd.json"
	var resp_file = temp_dir + "/resp.json"

	OS.execute("mkdir", ["-p", temp_dir], [], true)

	# Write command
	var f = FileAccess.open(cmd_file, FileAccess.WRITE)
	if f == null:
		return {"status": "error", "message": "Failed to write command"}
	f.store_string(JSON.stringify(cmd))
	f.close()

	# Execute Python script
	var script_path = ProjectSettings.globalize_path("res://addons/ros2_native/core/rcl_node_script.py")
	var output = []
	OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('rcl_node_script', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with open('%s', 'r') as f:
    cmd = json.load(f)

node = module.RclNodeScript()
node.process_command(cmd)

with open('%s', 'w') as f:
    json.dump(node._last_response, f)
""" % (script_path.replace("\\", "\\\\"), script_path.replace("\\", "\\\\"), cmd_file.replace("\\", "\\\\"), resp_file.replace("\\", "\\\\"))], output, true)

	# Read response
	f = FileAccess.open(resp_file, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		OS.execute("rm", ["-rf", temp_dir], [], true)
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			return parsed

	return {"status": "error", "message": "No response"}


func _variant_to_py(v: Variant) -> Variant:
	if v is Dictionary:
		var result = {}
		for k in v:
			result[k] = _variant_to_py(v[k])
		return result
	elif v is Array:
		return v.map(func(x): return _variant_to_py(x))
	return v