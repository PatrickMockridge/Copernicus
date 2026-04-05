# ros2_future.gd
# ROS 2 Future for async operations

class_name ROS2Future

var _done: bool = false
var _cancelled: bool = false
var _result: Variant = null
var _error_code: int = 0
var _error_message: String = ""


func _init() -> void:
	pass


func wait_for_result(timeout_sec: float = -1.0) -> bool:
	if _done:
		return true

	if timeout_sec < 0:
		# Busy wait (not ideal, but simple)
		while not _done:
			pass
		return true
	else:
		var start = Time.get_ticks_msec()
		while not _done:
			if (Time.get_ticks_msec() - start) >= (timeout_sec * 1000.0):
				return false
		return true


func get_result() -> Variant:
	return _result


func set_result(result: Variant) -> void:
	_result = result
	_done = true


func get_error() -> String:
	return _error_message


func get_error_code() -> int:
	return _error_code


func is_done() -> bool:
	return _done


func is_cancelled() -> bool:
	return _cancelled


func cancel() -> void:
	_cancelled = true
	_done = true


func get_code() -> int:
	return _error_code


func get_message() -> String:
	return _error_message


func is_error() -> bool:
	return _error_code != 0
