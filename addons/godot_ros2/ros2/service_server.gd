# service_server.gd
# ROS 2 Service Server

class_name ServiceServer

var _service_name: String
var _service_type: String
var _callback: Callable
var _pending_requests: Array = []


func _init(service: String, srv_type: String, cb: Callable) -> void:
	_service_name = service
	_service_type = srv_type
	_callback = cb


func get_service_name() -> String:
	return _service_name


func get_service_type() -> String:
	return _service_type


func _receive_request(request: Dictionary) -> void:
	_pending_requests.append(request)


func trigger_callback(request: Dictionary) -> Dictionary:
	if _callback.is_valid():
		return _callback.call(request)
	return {}


func get_next_request() -> Dictionary:
	if _pending_requests.is_empty():
		return {}
	return _pending_requests.pop_front()


func has_pending_request() -> bool:
	return not _pending_requests.is_empty()


func send_response(request_id: String, response: Dictionary) -> void:
	# In real implementation, send via ROS 2 service bridge
	pass


func get_pending_count() -> int:
	return _pending_requests.size()
