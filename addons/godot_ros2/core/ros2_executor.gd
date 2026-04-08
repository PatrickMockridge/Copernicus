# ros2_executor.gd
# ROS 2 executor for spinning
#
# NOTE: Removed all cross-file type annotations to resolve Godot 4.4 parse errors.
# This is a workaround - see docs/ROS2-godot4-parse-errors.md for details.

class_name ROS2Executor

const _ROS2_TIMER_PATH = "res://addons/godot_ros2/core/ros2_timer.gd"

var _nodes: Array = []
var _timers: Dictionary = {}
var _running: bool = false


func _init() -> void:
	pass


func add_node(node) -> void:
	_nodes.append(node)


func remove_node(node) -> void:
	_nodes.erase(node)


func spin_some(delta: float) -> void:
	# Process subscriptions
	for node in _nodes:
		_process_subscriptions(node)
		_process_services(node)
		_process_actions(node)


func spin_once() -> void:
	for node in _nodes:
		_process_subscriptions(node)


func spin_until_future_complete(future, timeout_sec: float = -1.0) -> void:
	var elapsed = 0.0
	while not future.is_done():
		system("sleep 0.001")
		elapsed += 0.001
		if timeout_sec > 0 and elapsed >= timeout_sec:
			break


func _process_subscriptions(node) -> void:
	for sub in node.get_subscriptions():
		if sub.has_new_message():
			var msg = sub.get_next_message()
			sub.trigger_callback(msg)


func _process_services(node) -> void:
	for server in node.get_service_servers():
		if server.has_pending_request():
			var request = server.get_next_request()
			server.trigger_callback(request)


func _process_actions(node) -> void:
	for server in node.get_action_servers():
		if server.has_new_goal():
			server.process_goal()
		if server.has_cancel_request():
			server.process_cancel()


func create_timer(period: float, callback: Callable):
	var timer_class = load(_ROS2_TIMER_PATH)
	var timer = timer_class.new(period, callback)
	_timers[timer] = true
	return timer


func remove_timer(timer) -> void:
	_timers.erase(timer)


func clear_timers() -> void:
	_timers.clear()


func system(cmd: String) -> void:
	var output = []
	OS.execute("sh", ["-c", cmd], output, false)
