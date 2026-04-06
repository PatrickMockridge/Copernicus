# performance_monitor.gd
# Performance monitoring plugin

extends SimulatorPlugin

var _fps_history: Array = []
var _physics_step_times: Array = []
var _max_history: int = 1000


func _init(name: String = "PerformanceMonitor") -> void:
	super(name)


func on_simulation_step(delta: float) -> void:
	var fps = 1.0 / delta if delta > 0 else 0.0
	_fps_history.append(fps)
	if _fps_history.size() > _max_history:
		_fps_history.pop_front()


func get_average_fps() -> float:
	if _fps_history.is_empty():
		return 0.0
	var sum = 0.0
	for f in _fps_history:
		sum += f
	return sum / _fps_history.size()


func get_min_fps() -> float:
	if _fps_history.is_empty():
		return 0.0
	var min_val = INF
	for f in _fps_history:
		if f < min_val:
			min_val = f
	return min_val


func get_max_fps() -> float:
	if _fps_history.is_empty():
		return 0.0
	var max_val = -INF
	for f in _fps_history:
		if f > max_val:
			max_val = f
	return max_val


func get_statistics() -> Dictionary:
	return {
		"average_fps": get_average_fps(),
		"min_fps": get_min_fps(),
		"max_fps": get_max_fps(),
		"samples": _fps_history.size()
	}