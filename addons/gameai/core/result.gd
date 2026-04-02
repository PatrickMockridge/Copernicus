# result.gd
# Simple Result type for GameAI SDK

class_name Result

var _ok: bool
var _value: Variant
var _error: Dictionary


func _init(ok: bool, value: Variant = null, error: Dictionary = {}):
	_ok = ok
	_value = value
	_error = error


static func ok(value: Variant = null) -> Result:
	return Result.new(true, value)


static func err(error: Variant) -> Result:
	var err_dict = {"code": -1, "message": str(error)}
	if error is Dictionary:
		err_dict = error
	return Result.new(false, null, err_dict)


func is_ok() -> bool:
	return _ok


func is_err() -> bool:
	return not _ok


func ok_value() -> Variant:
	return _value


func err_value() -> Dictionary:
	return _error


func get_or_default(default_value: Variant) -> Variant:
	return _value if _ok else default_value
