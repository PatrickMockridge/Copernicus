# publisher.gd
# ROS 2 Publisher

class_name Publisher

var _topic_name: String
var _message_type: String
var _QoS: QoSProfile
var _message_queue: Array = []
var _sequence_number: int = 0
var _bridge_client: ROS2BridgeClient = null
var _use_udp: bool = true


func _init(topic: String, msg_type: String, qos: QoSProfile) -> void:
	_topic_name = topic
	_message_type = msg_type
	_QoS = qos


func get_topic() -> String:
	return _topic_name


func get_type() -> String:
	return _message_type


func get_qos() -> QoSProfile:
	return _QoS


func set_bridge_client(client: ROS2BridgeClient) -> void:
	_bridge_client = client


func get_bridge_client() -> ROS2BridgeClient:
	return _bridge_client


func publish(message: Dictionary) -> void:
	_message_queue.append(message)
	_sequence_number += 1
	_send_to_ros(message)


func publish_raw(message: Dictionary) -> void:
	publish(message)


func _send_to_ros(message: Dictionary) -> void:
	# Send via bridge if connected, otherwise queue
	if _bridge_client and _bridge_client.is_bridge_connected():
		if _use_udp:
			_bridge_client.publish_udp(_topic_name, message)
		else:
			# TCP publish would go through bridge's TCP handler
			pass


func has_next() -> bool:
	return not _message_queue.is_empty()


func get_next() -> Dictionary:
	if _message_queue.is_empty():
		return {}
	return _message_queue.pop_front()


func get_sequence_number() -> int:
	return _sequence_number


func is_valid() -> bool:
	return not _topic_name.is_empty() and not _message_type.is_empty()