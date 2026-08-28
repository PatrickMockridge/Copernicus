# joint_trajectory_handler.gd
# Handles time-parameterized joint trajectory execution for industrial robots

class_name JointTrajectoryHandler
extends RefCounted

## Signals

signal point_reached(point_index: int)
signal trajectory_started()
signal trajectory_completed()
signal trajectory_aborted()
signal error(message: String)


## ===== Configuration =====

## Trajectory points from MoveIt! or similar planners
## Format: Array of {
##   "positions": Array[float],
##   "velocities": Array[float] (optional),
##   "accelerations": Array[float] (optional),
##   "time_from_start": float (seconds)
## }
var _trajectory: Array = []

var _joint_count: int = 6
var _execution_speed: float = 1.0  # 0.0-1.0, multiplier for execution speed


## ===== Execution State =====

var _is_executing: bool = false
var _current_point_index: int = 0
var _start_time: float = 0.0
var _last_point_time: float = 0.0

## Interpolation state
var _interpolating: bool = false
var _interpolation_start: float = 0.0
var _interpolation_duration: float = 0.0
var _interpolation_from: Array = []
var _interpolation_to: Array = []


## ===== Backend Reference =====

var _backend: IndustrialBackend


func _init() -> void:
	pass


## Set the backend for trajectory execution
func set_backend(backend: IndustrialBackend) -> void:
	_backend = backend


## Configure trajectory
## trajectory = Array of trajectory points
func set_trajectory(trajectory_points: Array) -> void:
	_trajectory = trajectory_points
	_current_point_index = 0
	_is_executing = false


## Set execution speed multiplier (0.0 to 1.0)
func set_speed(speed: float) -> void:
	_execution_speed = clamp(speed, 0.0, 1.0)


## Start trajectory execution
func execute() -> bool:
	if _trajectory.size() == 0:
		error.emit("No trajectory points set")
		return false

	if _backend == null:
		error.emit("No backend configured")
		return false

	_is_executing = true
	_current_point_index = 0
	_start_time = Time.get_ticks_msec() / 1000.0
	_last_point_time = 0.0

	trajectory_started.emit()
	_execute_current_point()
	return true


## Abort trajectory execution
func abort() -> void:
	if not _is_executing:
		return

	_is_executing = false
	_backend.abort_trajectory()
	trajectory_aborted.emit()


## Get current point index
func get_current_point_index() -> int:
	return _current_point_index


## Get trajectory progress (0.0 to 1.0)
func get_trajectory_progress() -> float:
	if _trajectory.size() == 0:
		return 0.0

	if _current_point_index >= _trajectory.size():
		return 1.0

	return float(_current_point_index) / float(_trajectory.size())


## Process trajectory execution (call from physics process)
func process(delta: float) -> void:
	if not _is_executing:
		return

	var current_time = Time.get_ticks_msec() / 1000.0 - _start_time

	## Handle interpolation between points
	if _interpolating:
		var elapsed = current_time - _interpolation_start
		var t = clamp(elapsed / _interpolation_duration, 0.0, 1.0)

		if t >= 1.0:
			_interpolating = false
			_advance_to_next_point()
		return

	## Check if we should advance to next point based on time_from_start
	if _current_point_index < _trajectory.size():
		var point = _trajectory[_current_point_index]
		var target_time = point.get("time_from_start", 0.0) * (1.0 / _execution_speed)

		if current_time >= target_time:
			_advance_to_next_point()


func _execute_current_point() -> void:
	if _current_point_index >= _trajectory.size():
		_is_executing = false
		trajectory_completed.emit()
		return

	var point = _trajectory[_current_point_index]
	var positions = point.get("positions", [])

	if _backend.is_connection_open():
		_backend.move_joints(positions)

	point_reached.emit(_current_point_index)

	## Schedule interpolation check
	var next_time = _get_next_point_time()
	if next_time > 0:
		_schedule_interpolation(positions, next_time)


func _advance_to_next_point() -> void:
	_current_point_index += 1

	if _current_point_index >= _trajectory.size():
		_is_executing = false
		trajectory_completed.emit()
		return

	_execute_current_point()


func _get_next_point_time() -> float:
	if _current_point_index + 1 >= _trajectory.size():
		return 0.0

	var current_point = _trajectory[_current_point_index]
	var next_point = _trajectory[_current_point_index + 1]

	var current_time = current_point.get("time_from_start", 0.0)
	var next_time = next_point.get("time_from_start", 0.0)

	return (next_time - current_time) * (1.0 / _execution_speed)


func _schedule_interpolation(from_positions: Array, duration: float) -> void:
	_interpolating = true
	_interpolation_start = Time.get_ticks_msec() / 1000.0 - _start_time
	_interpolation_duration = duration
	_interpolation_from = from_positions
	if _current_point_index + 1 < _trajectory.size():
		_interpolation_to = _trajectory[_current_point_index + 1].get("positions", [])
	else:
		_interpolation_to = from_positions


## Get interpolated joint positions at current time
func get_interpolated_positions() -> Array:
	if not _interpolating:
		if _current_point_index < _trajectory.size():
			return _trajectory[_current_point_index].get("positions", [])
		return []

	var t = clamp(
		(Time.get_ticks_msec() / 1000.0 - _start_time - _interpolation_start) / _interpolation_duration,
		0.0, 1.0
	)

	var result = []
	for i in range(_interpolation_from.size()):
		var from_val = _interpolation_from[i]
		var to_val = _interpolation_to[i] if i < _interpolation_to.size() else from_val
		result.append(from_val + (to_val - from_val) * t)

	return result


## ===== Utility =====

## Check if trajectory is executing
func is_executing() -> bool:
	return _is_executing


## Get total trajectory duration in seconds
func get_duration() -> float:
	if _trajectory.size() == 0:
		return 0.0

	var last_point = _trajectory[_trajectory.size() - 1]
	return last_point.get("time_from_start", 0.0) * (1.0 / _execution_speed)


## Reset handler state
func reset() -> void:
	_trajectory = []
	_current_point_index = 0
	_is_executing = false
	_interpolating = false