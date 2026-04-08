# subscription.gd
# ROS 2 Subscription
#
# NOTE: Removed cross-file type annotations to resolve Godot 4.4 parse errors.

class_name Subscription

var _topic_name: String
var _message_type: String
var _callback: Callable
var _QoS
var _message_queue: Array = []
var _last_message: Dictionary = {}
var _bridge_client = null


func _init(topic: String, msg_type: String, cb: Callable, qos) -> void:
	_topic_name = topic
	_message_type = msg_type
	_callback = cb
	_QoS = qos


func get_topic() -> String:
	return _topic_name


func get_type() -> String:
	return _message_type


func get_qos():
	return _QoS


func set_bridge_client(client) -> void:
	_bridge_client = client


func get_bridge_client():
	return _bridge_client


func _receive_message(message: Dictionary) -> void:
	_last_message = message
	_message_queue.append(message)


func has_new_message() -> bool:
	# Check bridge for new messages
	if _bridge_client and _bridge_client.is_bridge_connected():
		var messages = _bridge_client.receive_messages()
		if _topic_name in messages:
			var msg = messages[_topic_name]
			_receive_message(msg)

	return not _message_queue.is_empty()


func get_next_message() -> Dictionary:
	if _message_queue.is_empty():
		return _last_message
	return _message_queue.pop_front()


func trigger_callback(message: Dictionary) -> void:
	if _callback.is_valid():
		_callback.call(message)


func get_last_message() -> Dictionary:
	return _last_message


func clear_queue() -> void:
	_message_queue.clear()
