# mock_industrial.gd
# Mock industrial backend for testing without hardware
# Simulates robot behavior for development and testing

class_name MockIndustrial
extends IndustrialBackend

## ===== Configuration =====

var _robot_ip: String = ""
var _port: int = 50230
var _timeout: float = 5.0
var _joint_count: int = 6

var _simulated_delay: float = 0.01  # seconds


## ===== Connection State =====

var _connected: bool = false
var _connecting: bool = false


## ===== Robot State =====

var _joint_positions: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _joint_velocities: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _joint_torques: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

var _mode: int = 1  # 0=teach, 1=run, 2=stop, 3=error
var _e_stop_triggered: bool = false
var _error_code: int = 0
var _controller_temperature: float = 35.0

var _digital_inputs: Array = [false, false, false, false, false, false, false, false]
var _digital_outputs: Array = [false, false, false, false, false, false, false, false]

var _registers: Dictionary = {}


## ===== Trajectory State =====

var _is_trajectory_running: bool = false
var _trajectory_points: Array = []
var _current_trajectory_index: int = 0
var _trajectory_start_time: float = 0.0


## ===== Static Methods =====

static func get_backend_name() -> String:
	return "MockIndustrial"


static func get_backend_description() -> String:
	return "Mock industrial robot for testing. Simulates MOTOMAN/ABB behavior without hardware."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "No requirements - always available for testing."


## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_robot_ip = config.get("robot_ip", "")
	_port = config.get("port", 50230)
	_timeout = config.get("timeout", 5.0)
	_joint_count = config.get("joint_count", 6)

	## Initialize joint arrays based on joint count
	_joint_positions = []
	_joint_velocities = []
	_joint_torques = []
	for i in range(_joint_count):
		_joint_positions.append(0.0)
		_joint_velocities.append(0.0)
		_joint_torques.append(0.0)

	emit_signal("backend_initialized", true)
	return true


func shutdown() -> void:
	disconnect()


## ===== Connection =====

func connect(address: String) -> bool:
	_robot_ip = address
	_connecting = true

	## Simulate connection delay
	await get_tree().create_timer(_simulated_delay).timeout

	_connected = true
	_connecting = false

	emit_signal("connection_changed", true)
	return true


func disconnect() -> void:
	if not _connected:
		return

	_abort_trajectory_internal()
	_connected = false
	emit_signal("connection_changed", false)


func is_connected() -> bool:
	return _connected


## ===== Robot Status =====

func get_robot_status() -> Dictionary:
	if not _connected:
		return {}

	## Simulate some state changes
	_update_simulated_state()

	return {
		"mode": _mode,
		"e_stop_triggered": _e_stop_triggered,
		"error_code": _error_code,
		"joint_positions": _joint_positions.duplicate(),
		"joint_velocities": _joint_velocities.duplicate(),
		"joint_torques": _joint_torques.duplicate(),
		"controller_temperature": _controller_temperature,
		"digital_inputs": _digital_inputs.duplicate(),
		"digital_outputs": _digital_outputs.duplicate(),
		"timestamp": Time.get_datetime_dict_from_system()
	}


func get_joint_positions() -> Array:
	return _joint_positions.duplicate()


func get_joint_velocities() -> Array:
	return _joint_velocities.duplicate()


func get_joint_torques() -> Array:
	return _joint_torques.duplicate()


## ===== Joint Trajectory =====

func send_joint_trajectory(trajectory: Array) -> bool:
	if not _connected:
		return false

	_trajectory_points = trajectory
	return true


func execute_trajectory(points: Array) -> bool:
	if not _connected:
		return false

	_trajectory_points = points
	_current_trajectory_index = 0
	_trajectory_start_time = Time.get_ticks_msec() / 1000.0
	_is_trajectory_running = true

	## Simulate trajectory execution asynchronously
	_process_trajectory()
	return true


func abort_trajectory() -> void:
	_abort_trajectory_internal()


func is_trajectory_running() -> bool:
	return _is_trajectory_running


## ===== Motion Control =====

func move_joints(positions: Array) -> bool:
	if not _connected:
		return false

	## Validate position count
	if positions.size() != _joint_count:
		push_warning("MockIndustrial: position count mismatch")
		return false

	## Smoothly interpolate to target positions
	for i in range(_joint_count):
		_joint_positions[i] = positions[i]

	return true


func move_cartesian(position: Vector3, orientation: Quaternion) -> bool:
	if not _connected:
		return false

	## Mock - just acknowledge (in real impl, would do IK)
	print("MockIndustrial: move_cartesian to ", position)
	return true


## ===== Safety =====

func trigger_eston() -> void:
	_e_stop_triggered = true
	_mode = 2  # STOP
	_abort_trajectory_internal()
	emit_signal("error_occurred", "E-Stop triggered")


func clear_eston() -> void:
	_e_stop_triggered = false
	_mode = 1  # RUN
	_error_code = 0


## ===== Digital I/O =====

func read_digital_input(index: int) -> bool:
	if index >= 0 and index < _digital_inputs.size():
		return _digital_inputs[index]
	return false


func write_digital_output(index: int, value: bool) -> bool:
	if index >= 0 and index < _digital_outputs.size():
		_digital_outputs[index] = value
		return true
	return false


## ===== Registers =====

func read_register(address: int) -> float:
	return _registers.get(address, 0.0)


func write_register(address: int, value: float) -> bool:
	_registers[address] = value
	return true


## ===== Internal Methods =====

func _update_simulated_state() -> void:
	## Simulate small random movements and temperature changes
	for i in range(_joint_count):
		_joint_velocities[i] = randf() * 0.1 - 0.05
		_joint_torques[i] = randf() * 10.0 - 5.0

	_controller_temperature += randf() * 0.2 - 0.1
	_controller_temperature = clamp(_controller_temperature, 30.0, 60.0)


func _process_trajectory() -> void:
	if not _is_trajectory_running:
		return

	var current_time = Time.get_ticks_msec() / 1000.0 - _trajectory_start_time

	while _current_trajectory_index < _trajectory_points.size():
		var point = _trajectory_points[_current_trajectory_index]
		var point_time = point.get("time_from_start", 0.0)

		if current_time >= point_time:
			var positions = point.get("positions", [])
			if positions.size() == _joint_count:
				for i in range(_joint_count):
					_joint_positions[i] = positions[i]

			_current_trajectory_index += 1
			emit_signal("point_reached", _current_trajectory_index - 1)
		else:
			break

	if _current_trajectory_index >= _trajectory_points.size():
		_is_trajectory_running = false
		emit_signal("trajectory_complete", true)
	else:
		## Schedule next check
		await get_tree().create_timer(0.016).timeout
		_process_trajectory()


func _abort_trajectory_internal() -> void:
	_is_trajectory_running = false
	_trajectory_points.clear()
	_current_trajectory_index = 0


## ===== Simulation Control (for testing) =====

func set_joint_positions(positions: Array) -> void:
	for i in range(min(positions.size(), _joint_count)):
		_joint_positions[i] = positions[i]


func set_mode(mode: int) -> void:
	_mode = mode


func set_error_code(code: int) -> void:
	_error_code = code


func trigger_simulated_error() -> void:
	_error_code = 999
	_mode = 3  # ERROR
	emit_signal("error_occurred", "Simulated error 999")