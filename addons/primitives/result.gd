# result.gd
# Unified Result type for all SDK operations

class_name Result

var _success: bool
var _data: Variant
var _error_message: String
var _error_code: int


func _init(success: bool, data: Variant = null, error_msg: String = "", error_code: int = 0) -> void:
	_success = success
	_data = data
	_error_message = error_msg
	_error_code = error_code


static func ok(data: Variant = null) -> Result:
	return Result.new(true, data)


static func err(message: String, code: int = -1) -> Result:
	return Result.new(false, null, message, code)


func is_ok() -> bool:
	return _success


func is_err() -> bool:
	return not _success


func get_data() -> Variant:
	return _data


func get_error() -> String:
	return _error_message


func get_error_code() -> int:
	return _error_code


func if_ok(callback: Callable) -> Result:
	if _success and callback.is_valid():
		callback.call(_data)
	return self


func if_err(callback: Callable) -> Result:
	if not _success and callback.is_valid():
		callback.call(_error_message)
	return self


func _to_string() -> String:
	if _success:
		return "Result.Ok(%s)" % str(_data)
	return "Result.Err(%s)" % _error_message
