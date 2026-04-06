# physics_logger.gd
# Physics logging plugin

extends SimulatorPlugin

var _log_file: FileAccess
var _log_path: String = ""
var _logged_bodies: Array = []


func _init(name: String = "PhysicsLogger") -> void:
	super(name)


func set_log_path(path: String) -> void:
	_log_path = path


func add_body(body_name: String) -> void:
	_logged_bodies.append(body_name)


func on_load(simulator: ROS2Simulator) -> void:
	super.on_load(simulator)
	if not _log_path.is_empty():
		_log_file = FileAccess.open(_log_path, FileAccess.WRITE)


func on_physics_step(delta: float) -> void:
	if _log_file:
		var data = {"time": _simulator.get_sim_time(), "bodies": {}}
		_log_file.store_line(JSON.stringify(data))
		_log_file.flush()


func on_unload() -> void:
	if _log_file:
		_log_file.close()