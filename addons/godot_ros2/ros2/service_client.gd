# service_client.gd
# ROS 2 Service Client
#
# NOTE: Removed cross-file type annotations to resolve Godot 4.4 parse errors.

class_name ServiceClient

const _ROS2_FUTURE_PATH = "res://addons/godot_ros2/core/ros2_future.gd"

var _service_name: String
var _service_type: String
var _pending_requests: Dictionary = {}
var _request_id: int = 0


func _init(service: String, srv_type: String) -> void:
	_service_name = service
	_service_type = srv_type


func get_service_name() -> String:
	return _service_name


func get_service_type() -> String:
	return _service_type


func call_service(request: Dictionary):
	var future_class = load(_ROS2_FUTURE_PATH)
	var future = future_class.new()
	var request_id = _generate_request_id()
	_pending_requests[request_id] = future
	_send_request(request_id, request)
	return future


func call_service_async(request: Dictionary, callback: Callable) -> void:
	var future = call_service(request)
	# In real impl, would poll for completion
	if callback.is_valid():
		callback.call(future)


func _send_request(request_id: String, request: Dictionary) -> void:
	# In real implementation, send via ROS 2 service bridge
	pass


func _receive_response(request_id: String, response: Dictionary) -> void:
	if request_id in _pending_requests:
		var future = _pending_requests[request_id]
		future.set_result(response)
		_pending_requests.erase(request_id)


func _generate_request_id() -> String:
	_request_id += 1
	return "request_%d" % _request_id


func get_pending_count() -> int:
	return _pending_requests.size()


func wait_for_service(timeout_sec: float = -1.0) -> bool:
	# Would check if service is available
	return true
