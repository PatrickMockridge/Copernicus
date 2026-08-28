# industrial_backend.gd
# Abstract interface for industrial robot backends
# All industrial backends (MOTOMAN, ABB, UR, etc.) must implement this

class_name IndustrialBackend
extends CopernicusModule

## Signals

signal connection_changed(connected: bool)
signal status_update(status: Dictionary)
signal trajectory_complete(success: bool)
signal error_occurred(error: String)
signal io_changed(input_index: int, value: bool)
signal backend_initialized(success: bool)
signal point_reached(point_index: int)


## ===== Core Methods =====


static func get_module_category() -> String:
	return "industrial"





## Check if this backend is available (dependencies installed, etc)
static func is_available() -> bool:
	return false


## Get requirements for this backend (for error messages)
static func get_requirements() -> String:
	return ""


## Initialize the backend with configuration
## config = {
##   "robot_ip": String,
##   "port": int (optional),
##   "timeout": float (optional),
##   "joint_count": int (optional)
## }
func initialize(config: Dictionary) -> bool:
	push_error("IndustrialBackend.initialize() must be implemented by subclass")
	return false


## Shutdown the backend gracefully
func shutdown() -> void:
	push_error("IndustrialBackend.shutdown() must be implemented by subclass")


## ===== Connection =====

## Connect to robot controller
func open_connection(address: String) -> bool:
	push_error("IndustrialBackend.open_connection() must be implemented by subclass")
	return false


## Disconnect from robot controller
func close_connection() -> void:
	push_error("IndustrialBackend.close_connection() must be implemented by subclass")


## Check if connected
func is_connection_open() -> bool:
	push_error("IndustrialBackend.is_connection_open() must be implemented by subclass")
	return false


## ===== Robot Status =====

## Get current robot status
## Returns: {
##   "mode": int (0=teach, 1=run, 2=stop, 3=error),
##   "e_stop_triggered": bool,
##   "error_code": int,
##   "joint_positions": Array[float],
##   "joint_velocities": Array[float],
##   "joint_torques": Array[float],
##   "controller_temperature": float,
##   "timestamp": Dictionary
## }
func get_robot_status() -> Dictionary:
	push_error("IndustrialBackend.get_robot_status() must be implemented by subclass")
	return {}


## Get current joint positions
func get_joint_positions() -> Array:
	push_error("IndustrialBackend.get_joint_positions() must be implemented by subclass")
	return []


## Get current joint velocities
func get_joint_velocities() -> Array:
	push_error("IndustrialBackend.get_joint_velocities() must be implemented by subclass")
	return []


## Get current joint torques
func get_joint_torques() -> Array:
	push_error("IndustrialBackend.get_joint_torques() must be implemented by subclass")
	return []


## ===== Joint Trajectory =====

## Send joint trajectory to robot
## trajectory = Array of {
##   "positions": Array[float],
##   "velocities": Array[float] (optional),
##   "accelerations": Array[float] (optional),
##   "time_from_start": float (seconds)
## }
func send_joint_trajectory(trajectory: Array) -> bool:
	push_error("IndustrialBackend.send_joint_trajectory() must be implemented by subclass")
	return false


## Execute a trajectory (non-blocking)
func execute_trajectory(points: Array) -> bool:
	push_error("IndustrialBackend.execute_trajectory() must be implemented by subclass")
	return false


## Abort current trajectory execution
func abort_trajectory() -> void:
	push_error("IndustrialBackend.abort_trajectory() must be implemented by subclass")


## Check if trajectory is executing
func is_trajectory_running() -> bool:
	push_error("IndustrialBackend.is_trajectory_running() must be implemented by subclass")
	return false


## ===== Motion Control =====

## Move to joint positions (non-trajectory)
func move_joints(positions: Array) -> bool:
	push_error("IndustrialBackend.move_joints() must be implemented by subclass")
	return false


## Move to cartesian position
func move_cartesian(position: Vector3, orientation: Quaternion) -> bool:
	push_error("IndustrialBackend.move_cartesian() must be implemented by subclass")
	return false


## ===== Safety =====

## Trigger emergency stop
func trigger_estop() -> void:
	push_error("IndustrialBackend.trigger_estop() must be implemented by subclass")


## Clear emergency stop
func clear_estop() -> void:
	push_error("IndustrialBackend.clear_estop() must be implemented by subclass")


## ===== Digital I/O =====

## Read digital input
func read_digital_input(index: int) -> bool:
	push_error("IndustrialBackend.read_digital_input() must be implemented by subclass")
	return false


## Write digital output
func write_digital_output(index: int, value: bool) -> bool:
	push_error("IndustrialBackend.write_digital_output() must be implemented by subclass")
	return false


## ===== Registers =====

## Read numeric register
func read_register(address: int) -> float:
	push_error("IndustrialBackend.read_register() must be implemented by subclass")
	return 0.0


## Write numeric register
func write_register(address: int, value: float) -> bool:
	push_error("IndustrialBackend.write_register() must be implemented by subclass")
	return false