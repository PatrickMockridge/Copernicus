# industrial_controller.gd
# High-level industrial robot controller combining backend, trajectory, and monitoring
# Provides a unified interface for industrial robot operations

class_name IndustrialController
extends RefCounted

## ===== Components =====

var _backend: IndustrialBackend
var _trajectory_handler: JointTrajectoryHandler
var _status_monitor: RobotStatusMonitor


## ===== Configuration =====

var _robot_ip: String = ""
var _robot_name: String = "Unknown"


## ===== Signals =====

signal connected(robot_name: String)
signal disconnected()
signal status_changed(status: Dictionary)
signal trajectory_completed(success: bool)
signal error_occurred(message: String)


## ===== Initialization =====

func _init() -> void:
	_trajectory_handler = JointTrajectoryHandler.new()
	_status_monitor = RobotStatusMonitor.new()


## Configure with a specific backend
func configure(backend: IndustrialBackend) -> void:
	_backend = backend
	_trajectory_handler.set_backend(_backend)
	_status_monitor.set_backend(_backend)


## Connect to robot
func connect_robot(ip: String, backend_id: String = "MockIndustrial") -> bool:
	_robot_ip = ip

	# Create backend if not provided
	if _backend == null:
		_backend = ModuleRegistry.create("industrial", backend_id, {
			"robot_ip": ip,
			"joint_count": 6
		}) as IndustrialBackend

		if _backend == null:
			error_occurred.emit("Unknown industrial backend: " + backend_id)
			return false

		_trajectory_handler.set_backend(_backend)
		_status_monitor.set_backend(_backend)

	# Connect to robot
	if not _backend.open_connection(ip):
		error_occurred.emit("Failed to connect to %s at %s" % [backend_id, ip])
		return false

	# Start monitoring
	_status_monitor.start_monitoring(10.0)  # 10 Hz update rate
	_status_monitor.status_changed.connect(_on_status_changed)

	_robot_name = backend_id
	connected.emit(_robot_name)
	return true


## Disconnect from robot
func disconnect_robot() -> void:
	if _backend:
		_backend.close_connection()

	_status_monitor.stop_monitoring()
	_robot_name = "Unknown"

	disconnected.emit()


## ===== Connection State =====

func is_connection_open() -> bool:
	if _backend:
		return _backend.is_connection_open()
	return false


## ===== Robot Status =====

func get_robot_status() -> Dictionary:
	return _status_monitor.get_current_status()


func get_joint_positions() -> Array:
	return _status_monitor.get_joint_positions()


func get_mode() -> int:
	return _status_monitor.get_mode()


func get_mode_string() -> String:
	return RobotStatusMonitor.mode_to_string(get_mode())


func is_estop_triggered() -> bool:
	return _status_monitor.is_estop_triggered()


func is_in_error() -> bool:
	return _status_monitor.is_in_error()


## ===== Trajectory Execution =====

## Load a trajectory from array of points
func load_trajectory(trajectory_points: Array) -> void:
	_trajectory_handler.set_trajectory(trajectory_points)


## Execute the loaded trajectory
func execute_trajectory() -> bool:
	_trajectory_handler.trajectory_completed.connect(_on_trajectory_completed)
	_trajectory_handler.trajectory_aborted.connect(_on_trajectory_aborted)

	return _trajectory_handler.execute()


## Abort current trajectory
func abort_trajectory() -> void:
	_trajectory_handler.abort()
	_backend.abort_trajectory()


## Get trajectory progress (0.0 to 1.0)
func get_trajectory_progress() -> float:
	return _trajectory_handler.get_trajectory_progress()


## Get current point index
func get_current_point_index() -> int:
	return _trajectory_handler.get_current_point_index()


## ===== Direct Motion =====

## Move joints directly (non-trajectory)
func move_joints(positions: Array) -> bool:
	if _backend:
		return _backend.move_joints(positions)
	return false


## Move to Cartesian position
func move_cartesian(position: Vector3, orientation: Quaternion) -> bool:
	if _backend:
		return _backend.move_cartesian(position, orientation)
	return false


## ===== Safety =====

## Trigger emergency stop
func trigger_estop() -> void:
	if _backend:
		_backend.trigger_estop()


## Clear emergency stop
func clear_estop() -> void:
	if _backend:
		_backend.clear_estop()


## ===== I/O =====

func read_digital_input(index: int) -> bool:
	if _backend:
		return _backend.read_digital_input(index)
	return false


func write_digital_output(index: int, value: bool) -> bool:
	if _backend:
		return _backend.write_digital_output(index, value)
	return false


## ===== Registers =====

func read_register(address: int) -> float:
	if _backend:
		return _backend.read_register(address)
	return 0.0


func write_register(address: int, value: float) -> bool:
	if _backend:
		return _backend.write_register(address, value)
	return false


## ===== Status Display =====

func get_status_summary() -> String:
	return _status_monitor.get_status_summary()


func get_joint_positions_formatted() -> String:
	return _status_monitor.get_joint_positions_formatted()


## ===== Signal Handlers =====

func _on_status_changed(status: Dictionary) -> void:
	status_changed.emit(status)


func _on_trajectory_completed() -> void:
	trajectory_completed.emit(true)


func _on_trajectory_aborted() -> void:
	trajectory_completed.emit(false)


## ===== Utility =====

func get_robot_ip() -> String:
	return _robot_ip


func get_robot_name() -> String:
	return _robot_name


func get_backend_name() -> String:
	if _backend:
		return _backend.get_backend_name()
	return "None"


## Shutdown controller
func shutdown() -> void:
	disconnect_robot()
	_backend = null