# action_client.gd
# ROS 2 Action Client

class_name ActionClient

var _action_name: String
var _action_type: String
var _goals: Dictionary = {}
var _goal_id_counter: int = 0


func _init(action: String, act_type: String) -> void:
	_action_name = action
	_action_type = act_type


func get_action_name() -> String:
	return _action_name


func get_action_type() -> String:
	return _action_type


func send_goal(goal: Dictionary) -> ROS2Future:
	var future = ROS2Future.new()
	var goal_id = _generate_goal_id()
	_goals[goal_id] = {"future": future, "goal": goal}
	_send_goal_to_ros(goal_id, goal)
	return future


func send_goal_with_callback(goal: Dictionary, feedback_callback: Callable, result_callback: Callable) -> String:
	var goal_id = _generate_goal_id()
	var future = ROS2Future.new()
	_goals[goal_id] = {
		"future": future,
		"goal": goal,
		"feedback_callback": feedback_callback,
		"result_callback": result_callback
	}
	_send_goal_to_ros(goal_id, goal)
	return goal_id


func _send_goal_to_ros(goal_id: String, goal: Dictionary) -> void:
	# In real implementation, send via ROS 2 action bridge
	pass


func cancel_goal(goal_id: String) -> void:
	if goal_id in _goals:
		_goals[goal_id]["future"].cancel()
		_goals.erase(goal_id)


func cancel_all_goals() -> void:
	for goal_id in _goals:
		_goals[goal_id]["future"].cancel()
	_goals.clear()


func _receive_feedback(goal_id: String, feedback: Dictionary) -> void:
	if goal_id in _goals and "feedback_callback" in _goals[goal_id]:
		var cb = _goals[goal_id]["feedback_callback"]
		if cb.is_valid():
			cb.call(feedback)


func _receive_result(goal_id: String, result: Dictionary) -> void:
	if goal_id in _goals:
		_goals[goal_id]["future"].set_result(result)
		if "result_callback" in _goals[goal_id]:
			var cb = _goals[goal_id]["result_callback"]
			if cb.is_valid():
				cb.call(result)
		_goals.erase(goal_id)


func get_active_goals() -> Array:
	return _goals.keys()


func _generate_goal_id() -> String:
	_goal_id_counter += 1
	return "goal_%d_%d" % [Time.get_ticks_msec(), _goal_id_counter]
