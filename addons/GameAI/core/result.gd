# result.gd
# Simple Result type for GameAI SDK

class_name GameAIResult

var _ok: bool
var _value: Variant
var _error: Variant


func _init(ok: bool, value: Variant = null, error: Variant = null):
	_ok = ok
	_value = value
	_error = error


func is_ok() -> bool:
	return _ok


func is_err() -> bool:
	return not _ok


func ok_value() -> Variant:
	return _value


func err_value() -> Variant:
	return _error


func get_or_default(default_value: Variant) -> Variant:
	return _value if _ok else default_value
