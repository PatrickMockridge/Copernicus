# opcua_bridge.gd
# OPC-UA protocol bridge for industrial robots.
# Real connection via a persistent Python subprocess (opcua_bridge.py, asyncua).

class_name OpcuaBridge
extends IndustrialBackend

## ===== Configuration =====

var _robot_ip: String = ""
var _port: int = 4840
var _timeout: float = 5.0
var _joint_count: int = 6
var _node_id: String = ""

## OPC-UA node IDs (robot-specific). Populate via config so reads/writes are real.
var _joint_node_ids: Array = []
var _mode_node_id: String = ""
var _estop_node_id: String = ""
var _error_node_id: String = ""
var _temp_node_id: String = ""
var _io_input_node_ids: Array = []
var _io_output_node_ids: Array = []
var _register_node_ids: Array = []

## Optional IK solver for cartesian moves (IKSolver + chain).
var _ik_solver = null
var _ik_chain: Array = []

## Python bridge process
var _bridge: PythonBridge
var _bridge_port: int = 9890


## ===== Connection State =====

var _connected: bool = false
var _session_id: String = ""


## ===== Robot State =====

var _joint_positions: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _joint_velocities: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _joint_torques: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

var _mode: int = 1
var _e_stop_triggered: bool = false
var _error_code: int = 0
var _controller_temperature: float = 35.0


## ===== Trajectory =====

var _is_trajectory_running: bool = false


## ===== OPC-UA Common Node IDs =====

const NODEID_ROOT: String = "ns=0;i=84"  # Root folder
const NODEID_OBJECTS: String = "ns=0;i=85"  # Objects folder


## ===== Static Methods =====

static func get_module_name() -> String:
	return "OPC-UA"


static func get_module_description() -> String:
	return "OPC-UA industrial robot bridge. Supports any robot with OPC-UA server."


static func is_available() -> bool:
	# OPC-UA support requires the asyncua package.
	var result = OS.execute("python3", ["-c", "import asyncua; print('available')"], [], true)
	return result == OK


static func get_requirements() -> String:
	return "Requires robot OPC-UA server endpoint and opcua package."



static func get_module_category() -> String:
	return "industrial"

static func _static_init():
	ModuleRegistry.register("industrial", "OpcuaBridge", preload("res://addons/industrial/backends/opcua_bridge.gd"))
## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_robot_ip = config.get("robot_ip", "")
	_port = config.get("port", 4840)
	_timeout = config.get("timeout", 5.0)
	_joint_count = config.get("joint_count", 6)
	_node_id = config.get("node_id", "")
	_bridge_port = config.get("bridge_port", 9890)

	_joint_node_ids = config.get("joint_node_ids", [])
	_mode_node_id = config.get("mode_node_id", "")
	_estop_node_id = config.get("estop_node_id", "")
	_error_node_id = config.get("error_node_id", "")
	_temp_node_id = config.get("temp_node_id", "")
	_io_input_node_ids = config.get("io_input_node_ids", [])
	_io_output_node_ids = config.get("io_output_node_ids", [])
	_register_node_ids = config.get("register_node_ids", [])
	_ik_solver = config.get("ik_solver", null)
	_ik_chain = config.get("ik_chain", [])

	return _start_bridge()


func shutdown() -> void:
	close_connection()
	if _bridge:
		_bridge.shutdown()
		_bridge = null


## ===== Connection =====

func open_connection(address: String) -> bool:
	if _connected:
		return true

	# Accept "host", "host:port", or "opc.tcp://host:port".
	var host := address
	var port := _port
	if address.begins_with("opc.tcp://"):
		address = address.trim_prefix("opc.tcp://")
	var colon := address.rfind(":")
	if colon > 0 and address.substr(colon + 1).is_valid_int():
		host = address.substr(0, colon)
		port = int(address.substr(colon + 1))
	else:
		host = address

	_robot_ip = host
	_port = port

	var resp := _send_command({"cmd": "connect", "host": host, "port": port})
	if resp.get("status") != "ok":
		_connected = false
		error_occurred.emit("OPC-UA connect failed: " + str(resp.get("message", "unknown")))
		return false

	_connected = true
	_session_id = ""
	connection_changed.emit(true)
	return true


func close_connection() -> void:
	if not _connected:
		return

	_abort_trajectory_internal()
	_send_command({"cmd": "disconnect"})
	_connected = false
	_session_id = ""
	connection_changed.emit(false)


func is_connection_open() -> bool:
	return _connected


## ===== Robot Status =====

func get_robot_status() -> Dictionary:
	if not _connected:
		return {}

	if not _mode_node_id.is_empty():
		var v := _read_node(_mode_node_id)
		if v != null:
			_mode = int(v)
	if not _estop_node_id.is_empty():
		var v := _read_node(_estop_node_id)
		if v != null:
			_e_stop_triggered = bool(v)
	if not _error_node_id.is_empty():
		var v := _read_node(_error_node_id)
		if v != null:
			_error_code = int(v)
	if not _temp_node_id.is_empty():
		var v := _read_node(_temp_node_id)
		if v != null:
			_controller_temperature = float(v)

	var joints := get_joint_positions()
	if not joints.is_empty():
		_joint_positions = joints

	return {
		"mode": _mode,
		"e_stop_triggered": _e_stop_triggered,
		"error_code": _error_code,
		"joint_positions": _joint_positions.duplicate(),
		"joint_velocities": _joint_velocities.duplicate(),
		"joint_torques": _joint_torques.duplicate(),
		"controller_temperature": _controller_temperature,
		"timestamp": Time.get_datetime_dict_from_system()
	}


func get_joint_positions() -> Array:
	if not _connected or _joint_node_ids.is_empty():
		return _joint_positions.duplicate()
	var values := _read_nodes(_joint_node_ids)
	if values.is_empty():
		return _joint_positions.duplicate()
	return values


func get_joint_velocities() -> Array:
	return _joint_velocities.duplicate()


func get_joint_torques() -> Array:
	return _joint_torques.duplicate()


## ===== Joint Trajectory =====

func send_joint_trajectory(trajectory: Array) -> bool:
	if not _connected or _joint_node_ids.is_empty():
		return false
	return true


func execute_trajectory(points: Array) -> bool:
	if not _connected or _joint_node_ids.is_empty():
		return false

	_is_trajectory_running = true
	for point in points:
		var positions = point.get("positions", [])
		if not move_joints(positions):
			_is_trajectory_running = false
			trajectory_complete.emit(false)
			return false
		var time_from_start = point.get("time_from_start", 0.0)
		if time_from_start > 0.0:
			await (Engine.get_main_loop() as SceneTree).create_timer(time_from_start).timeout

	_is_trajectory_running = false
	trajectory_complete.emit(true)
	return true


func abort_trajectory() -> void:
	_abort_trajectory_internal()


func is_trajectory_running() -> bool:
	return _is_trajectory_running


## ===== Motion Control =====

func move_joints(positions: Array) -> bool:
	if not _connected:
		return false

	if positions.size() != _joint_count:
		return false

	if _joint_node_ids.is_empty():
		# No OPC-UA node mapping configured: cache locally but report success
		# only when a real write target exists.
		error_occurred.emit("OPC-UA joint_node_ids not configured")
		return false

	var node_ids := _joint_node_ids.slice(0, positions.size())
	var resp := _send_command({"cmd": "write_many", "node_ids": node_ids, "values": positions})
	if resp.get("status") != "ok":
		return false

	for i in range(positions.size()):
		_joint_positions[i] = positions[i]
	return true


func move_cartesian(position: Vector3, orientation: Quaternion) -> bool:
	if not _connected:
		return false

	if _ik_solver == null or _ik_chain.is_empty():
		error_occurred.emit("Cartesian move requires a configured IK solver (ik_solver + ik_chain)")
		return false

	if not _ik_solver.solve(_ik_chain, position):
		error_occurred.emit("Cartesian move: IK solve failed")
		return false

	# Convert solved rotations (revolute assumption) to joint positions about each axis.
	var rotations = _ik_solver.get_joint_rotations()
	var positions: Array = []
	for i in range(min(rotations.size(), _ik_chain.size())):
		var q: Quaternion = rotations[i]
		var axis: Vector3 = _ik_chain[i].get("axis", Vector3.UP)
		var angle: float = q.get_angle()
		if q.get_axis().dot(axis) < 0.0:
			angle = -angle
		positions.append(angle)

	return move_joints(positions)


## ===== Safety =====

func trigger_estop() -> void:
	if not _connected:
		return

	if not _estop_node_id.is_empty():
		_write_node(_estop_node_id, true)
	_e_stop_triggered = true
	abort_trajectory()
	error_occurred.emit("E-Stop triggered")


func clear_estop() -> void:
	if not _connected:
		return

	if not _estop_node_id.is_empty():
		_write_node(_estop_node_id, false)
	_e_stop_triggered = false
	_error_code = 0


## ===== Digital I/O =====

var _digital_inputs: Array = [false, false, false, false, false, false, false, false]
var _digital_outputs: Array = [false, false, false, false, false, false, false, false]
var _registers: Dictionary = {}


func read_digital_input(index: int) -> bool:
	if not _connected or index < 0 or index >= _io_input_node_ids.size():
		return false
	var v := _read_node(_io_input_node_ids[index])
	if v != null:
		_digital_inputs[index] = bool(v)
		return bool(v)
	return _digital_inputs[index]


func write_digital_output(index: int, value: bool) -> bool:
	if not _connected or index < 0 or index >= _io_output_node_ids.size():
		return false
	if _write_node(_io_output_node_ids[index], value):
		_digital_outputs[index] = value
		return true
	return false


## ===== Registers =====

func read_register(address: int) -> float:
	if not _connected or address < 0 or address >= _register_node_ids.size():
		return _registers.get(address, 0.0)
	var v := _read_node(_register_node_ids[address])
	if v != null:
		_registers[address] = float(v)
		return float(v)
	return _registers.get(address, 0.0)


func write_register(address: int, value: float) -> bool:
	if not _connected or address < 0 or address >= _register_node_ids.size():
		return false
	if _write_node(_register_node_ids[address], value):
		_registers[address] = value
		return true
	return false


## ===== Internal Methods =====

func _start_bridge() -> bool:
	var script_path = ProjectSettings.globalize_path("res://addons/industrial/backends/opcua_bridge.py")
	_bridge = PythonBridge.new()
	if not _bridge.start(script_path, _bridge_port, []):
		_bridge = null
		error_occurred.emit("OPC-UA bridge failed to start (asyncua not installed?)")
		return false
	return true


func _send_command(cmd: Dictionary) -> Dictionary:
	if not _bridge or not _bridge.is_bridge_connected():
		return {"status": "error", "message": "OPC-UA bridge not connected"}
	return _bridge.send(cmd)


func _read_node(node_id: String) -> Variant:
	var resp := _send_command({"cmd": "read", "node_id": node_id})
	if resp.get("status") != "ok":
		return null
	return resp.get("value", null)


func _read_nodes(node_ids: Array) -> Array:
	var resp := _send_command({"cmd": "read_many", "node_ids": node_ids})
	if resp.get("status") != "ok":
		return []
	return resp.get("values", [])


func _write_node(node_id: String, value: Variant) -> bool:
	var resp := _send_command({"cmd": "write", "node_id": node_id, "value": value})
	return resp.get("status") == "ok"


func _abort_trajectory_internal() -> void:
	_is_trajectory_running = false
