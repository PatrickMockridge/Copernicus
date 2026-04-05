# godot_ros2.gd
# Main entry point for Godot ROS 2 SDK

extends Node

const VERSION = "1.0.0"

var _node: ROS2Node
var _executor: ROS2Executor
var _bridge_client: ROS2BridgeClient
var _connected: bool = false
var _pending_init: bool = false


func _init() -> void:
	_node = null
	_bridge_client = null
	_executor = ROS2Executor.new()


func _process(delta: float) -> void:
	if _connected:
		_executor.spin_some(delta)


signal initialization_completed(success: bool)

func initialize(node_name: String, ns: String = "", bridge_host: String = "127.0.0.1") -> void:
	"""Initialize the ROS 2 node and connect to the bridge (async via signals)."""
	if _pending_init:
		return
	_pending_init = true
	_node = ROS2Node.new(node_name, ns)
	_bridge_client = ROS2BridgeClient.new(bridge_host)
	_bridge_client.bridge_connection_completed.connect(_on_bridge_connection_completed)
	_bridge_client.connect_bridge()


func _on_bridge_connection_completed(success: bool) -> void:
	if success:
		_node.set_bridge_client(_bridge_client)
		print("GodotROS2: Bridge connected")
		_connected = true
		initialization_completed.emit(true)
	else:
		print("GodotROS2: Bridge connection failed: " + _bridge_client.get_last_error())
		_connected = true
		initialization_completed.emit(false)
	_pending_init = false


func get_ros_node() -> ROS2Node:
	return _node


func get_executor() -> ROS2Executor:
	return _executor


func is_initialized() -> bool:
	return _connected


func is_bridge_connected() -> bool:
	if _bridge_client:
		return _bridge_client.is_bridge_connected()
	return false


func get_bridge_client() -> ROS2BridgeClient:
	return _bridge_client


func get_version() -> String:
	return VERSION


# Topic helpers
func create_publisher(topic_name: String, message_type: String) -> Publisher:
	if _node == null:
		return null
	return _node.create_publisher(topic_name, message_type)


func create_subscription(topic_name: String, message_type: String, callback: Callable) -> Subscription:
	if _node == null:
		return null
	return _node.create_subscription(topic_name, message_type, callback)


# Service helpers
func create_client(service_name: String, service_type: String) -> ServiceClient:
	if _node == null:
		return null
	return _node.create_client(service_name, service_type)


func create_service(service_name: String, service_type: String, callback: Callable) -> ServiceServer:
	if _node == null:
		return null
	return _node.create_service(service_name, service_type, callback)


# Action helpers
func create_action_client(action_name: String, action_type: String) -> ActionClient:
	if _node == null:
		return null
	return _node.create_action_client(action_name, action_type)


func create_action_server(action_name: String, action_type: String, execute_callback: Callable) -> ActionServer:
	if _node == null:
		return null
	return _node.create_action_server(action_name, action_type, execute_callback)


# File Manager helpers
func create_file_manager(robot_host: String = "", robot_ns: String = "") -> FileManager:
	# Create a FileManager for robot file editing
	# robot_host: Robot IP address (for SSH mode)
	# robot_ns: Robot namespace for ROS service mode
	return FileManager.new(robot_host, robot_ns)
