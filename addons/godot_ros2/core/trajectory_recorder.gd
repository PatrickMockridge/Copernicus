# trajectory_recorder.gd
# Trajectory recording plugin

extends SimulatorPlugin

var _trajectories: Dictionary = {}
var _recording: bool = false
var _current_time: float = 0.0


func _init(name: String = "TrajectoryRecorder") -> void:
	super(name)


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