# ros2_timer.gd
# ROS 2 timer for periodic callbacks

class_name ROS2Timer

var _period: float
var _callback: Callable
var _last_tick: int = 0
var _running: bool = false


func _init(period: float, callback: Callable) -> void:
	_period = period
	_callback = callback
	_last_tick = Time.get_ticks_msec()
	_running = true


func get_period() -> float:
	return _period


func set_period(period: float) -> void:
	_period = period


func is_running() -> bool:
	return _running


func start() -> void:
	_running = true
	_last_tick = Time.get_ticks_msec()


func stop() -> void:
	_running = false


func has_elapsed() -> bool:
	if not _running:
		return false
	var current = Time.get_ticks_msec()
	return (current - _last_tick) >= (_period * 1000.0)


func reset() -> void:
	_last_tick = Time.get_ticks_msec()


func execute() -> void:
	if has_elapsed():
		_callback.call()
		reset()
