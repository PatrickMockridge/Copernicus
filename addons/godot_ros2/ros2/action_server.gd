# action_server.gd
# ROS 2 Action Server

class_name ActionServer

var _action_name: String
var _action_type: String
var _execute_callback: Callable
var _active_goals: Dictionary = {}
var _pending_goals: Array = []
var _result: Dictionary = {}


func _init(action: String, act_type: String, exec_cb: Callable) -> void:
	_action_name = action
	_action_type = act_type
	_execute_callback = exec_cb


func get_action_name() -> String:
	return _action_name


func get_action_type() -> String:
	return _action_type


func _receive_goal(goal: Dictionary) -> void:
	_pending_goals.append(goal)


func has_new_goal() -> bool:
	return not _pending_goals.is_empty()


func get_next_goal() -> Dictionary:
	if _pending_goals.is_empty():
		return {}
	return _pending_goals.pop_front()


func process_goal() -> void:
	if _pending_goals.is_empty():
		return

	var goal = _pending_goals.pop_front()
	var goal_id = goal.get("goal_id", "unknown")

	# Execute the goal
	if _execute_callback.is_valid():
		var result = _execute_callback.call(goal)
		_result[goal_id] = result
		_active_goals.erase(goal_id)
		_publish_result(goal_id, result)


func _publish_result(goal_id: String, result: Dictionary) -> void:
	# In real implementation, publish to ROS 2 action result topic
	pass


func _publish_feedback(goal_id: String, feedback: Dictionary) -> void:
	# In real implementation, publish to ROS 2 action feedback topic
	pass


func has_cancel_request() -> bool:
	# Check for cancel requests
	return false


func process_cancel() -> void:
	# Handle cancel request
	pass


func execute(goal: Dictionary) -> void:
	# Start executing a goal
	var goal_id = goal.get("goal_id", "unknown")
	_active_goals[goal_id] = goal


func publish_feedback(feedback: Dictionary) -> void:
	var goal_id = feedback.get("goal_id", "")
	if not goal_id.is_empty():
		_publish_feedback(goal_id, feedback)


func succeeded(result: Dictionary) -> void:
	# Goal succeeded
	pass


func aborted(result: Dictionary) -> void:
	# Goal aborted
	pass


func canceled(result: Dictionary) -> void:
	# Goal canceled
	pass


func get_active_goal_ids() -> Array:
	return _active_goals.keys()
