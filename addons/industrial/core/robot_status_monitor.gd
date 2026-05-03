# robot_status_monitor.gd
# Real-time monitoring of industrial robot state

class_name RobotStatusMonitor
extends RefCounted

## Signals

signal status_changed(status: Dictionary)
signal mode_changed(mode: int)
signal e_stop_triggered()
signal error_occurred(error_code: int)
signal io_changed(input_index: int, value: bool)


## ===== Configuration =====

var _update_rate: float = 10.0  # Hz
var _last_io_states: Array = []


## ===== Backend Reference =====

var _backend: IndustrialBackend


## ===== State Cache =====

var _current_status: Dictionary = {
	"mode": 0,
	"e_stop_triggered": false,
	"error_code": 0,
	"joint_positions": [],
	"joint_velocities": [],
	"joint_torques": [],
	"controller_temperature": 0.0,
	"digital_inputs": [],
	"digital_outputs": [],
	"timestamp": {}
}


## ===== Internal =====

var _is_monitoring: bool = false
var _monitor_timer: float = 0.0


func _init() -> void:
	pass


## Set the backend for monitoring
func set_backend(backend: IndustrialBackend) -> void:
	_backend = backend


## Start monitoring at specified update rate
func start_monitoring(update_rate: float) -> void:
	_update_rate = update_rate
	_is_monitoring = true
	_monitor_timer = 0.0


## Stop monitoring
func stop_monitoring() -> void:
	_is_monitoring = false


## Process monitoring update (call from physics process)
func process(delta: float) -> void:
	if not _is_monitoring:
		return

	_monitor_timer += delta
	var interval = 1.0 / _update_rate

	if _monitor_timer >= interval:
		_monitor_timer = 0.0
		_update_status()


## Get current status (cached)
func get_current_status() -> Dictionary:
	return _current_status.duplicate(true)


## Get joint positions
func get_joint_positions() -> Array:
	return _current_status.get("joint_positions", []).duplicate()


## Get joint velocities
func get_joint_velocities() -> Array:
	return _current_status.get("joint_velocities", []).duplicate()


## Get joint torques
func get_joint_torques() -> Array:
	return _current_status.get("joint_torques", []).duplicate()


## Get robot mode
func get_mode() -> int:
	return _current_status.get("mode", 0)


## Get mode string for display
static func mode_to_string(mode: int) -> String:
	match mode:
		0: return "TEACH"
		1: return "RUN"
		2: return "STOP"
		3: return "ERROR"
		_: return "UNKNOWN"


## Check if robot is in error state
func is_in_error() -> bool:
	return _current_status.get("mode", 0) == 3


## Check if emergency stop is triggered
func is_estop_triggered() -> bool:
	return _current_status.get("e_stop_triggered", false)


## Get controller temperature
func get_controller_temperature() -> float:
	return _current_status.get("controller_temperature", 0.0)


func _update_status() -> void:
	if _backend == null:
		return

	var new_status = _backend.get_robot_status()
	var old_mode = _current_status.get("mode", 0)
	var old_estop = _current_status.get("e_stop_triggered", false)

	## Update cached status
	_current_status = new_status.duplicate(true)

	## Store in history
	var timestamp = Time.get_ticks_msec()
	_current_status["_timestamp"] = timestamp
	_status_history.append(_current_status)

	if _status_history.size() > _max_history_size:
		_status_history.pop_front()

	## Check for mode change
	var new_mode = new_status.get("mode", 0)
	if new_mode != old_mode:
		mode_changed.emit(new_mode)

	## Check for e-stop trigger
	var new_estop = new_status.get("e_stop_triggered", false)
	if new_estop and not old_estop:
		e_stop_triggered.emit()

	## Check for error
	var error_code = new_status.get("error_code", 0)
	if error_code != 0:
		error_occurred.emit(error_code)

	## Check digital I/O changes
	_check_io_changes(new_status)

	## Emit status changed
	status_changed.emit(_current_status.duplicate(true))


func _check_io_changes(status: Dictionary) -> void:
	var new_inputs = status.get("digital_inputs", [])
	var new_outputs = status.get("digital_outputs", [])

	## Compare with last states and emit signals for changes
	for i in range(min(new_inputs.size(), _last_io_states.size())):
		if new_inputs[i] != _last_io_states[i]:
			io_changed.emit(i, new_inputs[i])

	_last_io_states = new_inputs.duplicate()


## ===== Status Display Helpers =====

## Get a human-readable status summary
func get_status_summary() -> String:
	var mode_str = mode_to_string(_current_status.get("mode", 0))
	var estop = _current_status.get("e_stop_triggered", false)
	var temp = _current_status.get("controller_temperature", 0.0)

	var summary = "Mode: %s" % mode_str
	if estop:
		summary += " | E-STOP ACTIVE"
	summary += " | Temp: %.1fC" % temp

	return summary


## Get joint positions formatted for display
func get_joint_positions_formatted() -> String:
	var positions = _current_status.get("joint_positions", [])
	if positions.size() == 0:
		return "No data"

	var formatted = []
	for i in range(positions.size()):
		formatted.append("J%d: %.2f" % [i + 1, positions[i]])

	return " | ".join(formatted)


## ===== History (for debugging) =====

var _status_history: Array = []
var _max_history_size: int = 100


func get_history() -> Array:
	return _status_history.duplicate()


func clear_history() -> void:
	_status_history.clear()