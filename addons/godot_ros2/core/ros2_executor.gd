# ros2_executor.gd
# ROS 2 executor for spinning

class_name ROS2Executor

var _nodes: Array = []
var _timers: Dictionary = {}
var _running: bool = false


func _init() -> void:
	pass


func add_node(node: ROS2Node) -> void:
	_nodes.append(node)


func remove_node(node: ROS2Node) -> void:
	_nodes.erase(node)


func spin_some(delta: float) -> void:
	# Process subscriptions
	for node in _nodes:
		if node is ROS2Node:
			_process_subscriptions(node)
			_process_services(node)
			_process_actions(node)


func spin_once() -> void:
	for node in _nodes:
		if node is ROS2Node:
			_process_subscriptions(node)


func spin_until_future_complete(future: ROS2Future, timeout_sec: float = -1.0) -> void:
	var elapsed = 0.0
	while not future.is_done():
		system("sleep 0.001")
		elapsed += 0.001
		if timeout_sec > 0 and elapsed >= timeout_sec:
			break


func _process_subscriptions(node: ROS2Node) -> void:
	for sub in node.get_subscriptions():
		if sub.has_new_message():
			var msg = sub.get_next_message()
			sub.trigger_callback(msg)


func _process_services(node: ROS2Node) -> void:
	for server in node.get_service_servers():
		if server.has_pending_request():
			var request = server.get_next_request()
			server.trigger_callback(request)


func _process_actions(node: ROS2Node) -> void:
	for server in node.get_action_servers():
		if server.has_new_goal():
			server.process_goal()
		if server.has_cancel_request():
			server.process_cancel()


func create_timer(period: float, callback: Callable) -> ROS2Timer:
	var timer = ROS2Timer.new(period, callback)
	_timers[timer] = true
	return timer


func remove_timer(timer: ROS2Timer) -> void:
	_timers.erase(timer)


func clear_timers() -> void:
	_timers.clear()


func system(cmd: String) -> void:
	var output = []
	OS.execute("sh", ["-c", cmd], output, false)
