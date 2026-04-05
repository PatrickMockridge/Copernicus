# simulator_plugins.gd
# Plugin system for simulator extensions

class_name SimulatorPlugin

var _name: String
var _enabled: bool = true


func _init(name: String) -> void:
	_name = name


func get_name() -> String:
	return _name


func is_enabled() -> bool:
	return _enabled


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func on_load(simulator: ROS2Simulator) -> void:
	pass


func on_unload() -> void:
	pass


func on_simulation_step(delta: float) -> void:
	pass


func on_physics_step(delta: float) -> void:
	pass


# ===== Built-in Plugins =====


class PhysicsLogger extends SimulatorPlugin

	var _log_file: FileAccess
	var _log_path: String = ""
	var _logged_bodies: Array = []


	func _init(name: String = "PhysicsLogger").super(name) -> void:
		pass


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
			var data = {"time": simulator.get_sim_time(), "bodies": {}}
			_log_file.store_line(JSON.stringify(data))
			_log_file.flush()


	func on_unload() -> void:
		if _log_file:
			_log_file.close()


class ContactVisualizer extends SimulatorPlugin

	var _contact_markers: Array = []


	func _init(name: String = "ContactVisualizer").super(name) -> void:
		pass


	func on_physics_step(delta: float) -> void:
		var contacts = _simulator.get_contact_manager().get_contacts()
		# Create/remove debug markers for contacts
		for contact in contacts:
			_create_contact_marker(contact)


	func _create_contact_marker(contact: Dictionary) -> void:
		# Would create a debug sphere at contact position
		pass


class TrajectoryRecorder extends SimulatorPlugin

	var _trajectories: Dictionary = {}
	var _recording: bool = false
	var _current_time: float = 0.0


	func _init(name: String = "TrajectoryRecorder").super(name) -> void:
		pass


	func start_recording(body_name: String) -> void:
		_trajectories[body_name] = []
		_recording = true


	func stop_recording(body_name: String) -> Array:
		_recording = false
		return _trajectories.get(body_name, [])


	func on_physics_step(delta: float) -> void:
		if not _recording:
			return
		_current_time += delta


	func record_pose(body_name: String, pose: Transform3D) -> void:
		if _recording and body_name in _trajectories:
			_trajectories[body_name].append({
				"time": _current_time,
				"pose": pose
			})


class PerformanceMonitor extends SimulatorPlugin

	var _fps_history: Array = []
	var _physics_step_times: Array = []
	var _max_history: int = 1000


	func _init(name: String = "PerformanceMonitor").super(name) -> void:
		pass


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
