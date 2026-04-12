# ros2_native.gd
# ROS2 Native Integration plugin for Copernicus
# Provides native rclpy integration instead of TCP/UDP bridge

@tool
extends EditorPlugin

const RclNode = preload("res://addons/ros2_native/core/rcl_node.gd")
const DDSTransport = preload("res://addons/ros2_native/core/dds_transport.gd")
const IsaacROS = preload("res://addons/ros2_native/core/isaac_ros_bridge.gd")


func _enter_tree() -> void:
	print("ROS2 Native Integration plugin loaded")
	print("  Isaac ROS support: ", IsaacROS.is_isaac_available())


func _exit_tree() -> void:
	print("ROS2 Native Integration plugin unloaded")


## ===== Node Creation =====

## Create a ROS2 native node
func create_node(node_name: String) -> RclNode:
	var node = RclNode.new()
	node.initialize({"node_name": node_name})
	return node


## Create Isaac ROS node
func create_isaac_node(node_name: String) -> IsaacROS:
	var node = IsaacROS.new()
	node.initialize({"node_name": node_name})
	return node


## ===== DDS Transport =====

## Create DDS transport for fast pub/sub
func create_dds_transport() -> DDSTransport:
	return DDSTransport.new()


## ===== Utility =====

## Check if ROS2 is available
static func is_ros2_available() -> bool:
	return RclNode.is_rclpy_available()


## Check if Isaac ROS is available
static func is_isaac_available() -> bool:
	return IsaacROS.is_isaac_available()


## Get ROS2 distro
static func get_ros_distro() -> String:
	var result = OS.execute("echo", ["$ROS_DISTRO"], true)
	if result[0] == OK:
		var output = result[1].strip_edges()
		if output != "":
			return output
	return "unknown"


## Get plugin version
static func get_version() -> String:
	return "1.0.0"