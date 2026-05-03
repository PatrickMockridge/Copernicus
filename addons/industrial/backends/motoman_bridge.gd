# motoman_bridge.gd
# MOTOMAN industrial robot bridge via INRC4 protocol
# INRC4 is MOTOMAN's TCP-based robot control protocol (port 50230)

class_name MotomanBridge
extends IndustrialBackend

## ===== Configuration =====

var _robot_ip: String = ""
var _port: int = 50230
var _timeout: float = 5.0
var _joint_count: int = 6


## ===== Connection =====

var _socket: StreamPeerTCP
var _connected: bool = false
var _connection_mutex: bool = false  # Simple mutex for connection operations


## ===== Robot State =====

var _joint_positions: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _joint_velocities: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _joint_torques: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

var _mode: int = 1  # 0=teach, 1=run, 2=stop, 3=error
var _e_stop_triggered: bool = false
var _error_code: int = 0
var _controller_temperature: float = 35.0


## ===== Trajectory =====

var _is_trajectory_running: bool = false


## ===== INRC4 Protocol Constants =====

## Message types
const INRC4_STATUS_READ: int = 0x01
const INRC4_JOINT_WRITE: int = 0x02
const INRC4_JOINT_READ: int = 0x03
const INRC4_TRAJECTORY_START: int = 0x10
const INRC4_TRAJECTORY_POINT: int = 0x11
const INRC4_TRAJECTORY_ABORT: int = 0x12
const INRC4_ESTON_TRIGGER: int = 0x20
const INRC4_ESTON_CLEAR: int = 0x21
const INRC4_IO_READ: int = 0x30
const INRC4_IO_WRITE: int = 0x31
const INRC4_REGISTER_READ: int = 0x40
const INRC4_REGISTER_WRITE: int = 0x41


## ===== Static Methods =====

static func get_backend_name() -> String:
	return "MOTOMAN"


static func get_backend_description() -> String:
	return "MOTOMAN industrial robots via INRC4 protocol (port 50230). Requires MOTOMAN robot controller with INRC4 support."


static func is_available() -> bool:
	# TODO: Check if motoman_driver ROS 2 package is available
	return false


static func get_requirements() -> String:
	return "Requires ROS 2 motoman_driver package and MOTOMAN robot controller with INRC4 protocol enabled."


## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_robot_ip = config.get("robot_ip", "")
	_port = config.get("port", 50230)
	_timeout = config.get("timeout", 5.0)
	_joint_count = config.get("joint_count", 6)

	return true


func shutdown() -> void:
	disconnect()


## ===== Connection =====

func connect(address: String) -> bool:
	if _connected:
		return true

	_robot_ip = address
	_socket = StreamPeerTCP.new()
	_socket.set_read_timeout(_timeout)
	_socket.set_write_timeout(_timeout)

	var result = _socket.connect_to_host(_robot_ip, _port)
	if result == OK:
		# Wait for connection to establish
		var attempts = 0
		while _socket.get_status() == StreamPeerTCP.STATUS_CONNECTING and attempts < 50:
			await get_tree().create_timer(0.1).timeout
			attempts += 1

		if _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_connected = true
			connection_changed.emit(true)
			return true

	_connected = false
	error_occurred.emit("Failed to connect to MOTOMAN at %s:%d" % [_robot_ip, _port])
	return false


func disconnect() -> void:
	if not _connected:
		return

	_abort_trajectory_internal()
	_socket.disconnect_from_host()
	_connected = false
	connection_changed.emit(false)


func is_connected() -> bool:
	if _socket != null:
		return _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED
	return false


## ===== Robot Status =====

func get_robot_status() -> Dictionary:
	if not is_connected():
		return {}

	var response = _send_inrc4_command(INRC4_STATUS_READ, PackedByteArray())
	if response.size() > 0:
		return _parse_status_response(response)
	else:
		return _get_default_status()


func get_joint_positions() -> Array:
	if not is_connected():
		return []

	var response = _send_inrc4_command(INRC4_JOINT_READ, PackedByteArray())
	if response.size() >= _joint_count * 4:
		return _bytes_to_floats(response)
	return _joint_positions.duplicate()


func get_joint_velocities() -> Array:
	# INRC4 doesn't have separate velocity readout in basic protocol
	# Return zeros as placeholder
	return _joint_velocities.duplicate()


func get_joint_torques() -> Array:
	# INRC4 doesn't have separate torque readout in basic protocol
	# Return zeros as placeholder
	return _joint_torques.duplicate()


## ===== Joint Trajectory =====

func send_joint_trajectory(trajectory: Array) -> bool:
	if not is_connected():
		return false

	# Send trajectory start command
	var start_data = PackedByteArray()
	start_data.append(trajectory.size())  # Number of points
	var response = _send_inrc4_command(INRC4_TRAJECTORY_START, start_data)

	if response.size() == 0 or response[0] != 0:
		return false

	return true


func execute_trajectory(points: Array) -> bool:
	if not is_connected():
		return false

	# Start trajectory
	if not send_joint_trajectory(points):
		return false

	_is_trajectory_running = true

	# Send trajectory points
	for i in range(points.size()):
		var point = points[i]
		var positions = point.get("positions", [])

		var point_data = PackedByteArray()
		point_data.append(i)  # Point index

		# Add joint positions as floats
		for pos in positions:
			point_data.append_array(_float_to_bytes(pos))

		var response = _send_inrc4_command(INRC4_TRAJECTORY_POINT, point_data)

		if response.size() == 0 or response[0] != 0:
			_is_trajectory_running = false
			trajectory_complete.emit(false)
			return false

		# Wait for point timing
		var time_from_start = point.get("time_from_start", 0.0)
		await get_tree().create_timer(time_from_start).timeout

	_is_trajectory_running = false
	trajectory_complete.emit(true)
	return true


func abort_trajectory() -> void:
	_abort_trajectory_internal()


func is_trajectory_running() -> bool:
	return _is_trajectory_running


## ===== Motion Control =====

func move_joints(positions: Array) -> bool:
	if not is_connected():
		return false

	if positions.size() != _joint_count:
		push_warning("MotomanBridge: position count mismatch")
		return false

	var data = PackedByteArray()
	for pos in positions:
		data.append_array(_float_to_bytes(pos))

	var response = _send_inrc4_command(INRC4_JOINT_WRITE, data)

	if response.size() > 0 and response[0] == 0:
		# Success - update cached positions
		_joint_positions = positions.duplicate()
		return true

	return false


func move_cartesian(position: Vector3, orientation: Quaternion) -> bool:
	if not is_connected():
		return false

	# MOTOMAN INRC4 doesn't have direct cartesian move command
	# We need to compute IK locally and then move joints
	# For a 6-DOF arm, we can use analytical IK

	# Simple 6-DOF arm IK (simplified - assumes standard configuration)
	# This is a basic implementation - full version would need
	# proper calibration data and robot-specific IK
	var joint_positions = _compute_simple_ik(position, orientation)

	if joint_positions.size() == 0:
		push_warning("MotomanBridge: Failed to compute IK for target pose")
		return false

	# Use joint move with computed positions
	return move_joints(joint_positions)


func _compute_simple_ik(target_pos: Vector3, target_orient: Quaternion) -> Array:
	# Simplified analytical IK for standard 6-DOF arm
	# This is a placeholder - real implementation needs:
	# 1. DH parameters for specific robot
	# 2. Joint limits
	# 3. Singularity handling
	# 4. Wrist configuration (elbow up/down)

	# For now, return a home position + small offset based on target
	# Real implementation would use numerical IK
	var home = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

	# Distance from origin
	var dist = target_pos.length()

	# Scale joint movement based on distance
	if dist > 0.001:
		var scale = min(dist / 2.0, 0.5)  # Max 0.5 rad movement
		home[0] = atan2(target_pos.x, target_pos.z) * scale
		home[1] = target_pos.y * scale * 0.5
		home[2] = -target_pos.y * scale * 0.3

	return home


## ===== Safety =====

func trigger_estop() -> void:
	if not is_connected():
		return

	var response = _send_inrc4_command(INRC4_ESTON_TRIGGER, PackedByteArray())
	if response.size() > 0 and response[0] == 0:
		_e_stop_triggered = true
		_mode = 2  # STOP
		abort_trajectory()
		error_occurred.emit("E-Stop triggered via INRC4")


func clear_estop() -> void:
	if not is_connected():
		return

	var response = _send_inrc4_command(INRC4_ESTON_CLEAR, PackedByteArray())
	if response.size() > 0 and response[0] == 0:
		_e_stop_triggered = false
		_error_code = 0


## ===== Digital I/O =====

func read_digital_input(index: int) -> bool:
	if not is_connected():
		return false

	var data = PackedByteArray()
	data.append(index)

	var response = _send_inrc4_command(INRC4_IO_READ, data)

	if response.size() >= 2 and response[0] == 0:
		return response[1] != 0

	return false


func write_digital_output(index: int, value: bool) -> bool:
	if not is_connected():
		return false

	var data = PackedByteArray()
	data.append(index)
	data.append(1 if value else 0)

	var response = _send_inrc4_command(INRC4_IO_WRITE, data)

	return response.size() > 0 and response[0] == 0


## ===== Registers =====

func read_register(address: int) -> float:
	if not is_connected():
		return 0.0

	var data = PackedByteArray()
	data.append(address)

	var response = _send_inrc4_command(INRC4_REGISTER_READ, data)

	if response.size() >= 5 and response[0] == 0:
		return _bytes_to_float(response.slice(1, 5))

	return 0.0


func write_register(address: int, value: float) -> bool:
	if not is_connected():
		return false

	var data = PackedByteArray()
	data.append(address)
	data.append_array(_float_to_bytes(value))

	var response = _send_inrc4_command(INRC4_REGISTER_WRITE, data)

	return response.size() > 0 and response[0] == 0


## ===== INRC4 Protocol Helpers =====

func _send_inrc4_command(command_type: int, data: PackedByteArray) -> PackedByteArray:
	if not is_connected():
		return PackedByteArray()

	# Build INRC4 message
	var message = PackedByteArray()

	# Header (4 bytes)
	message.append(0x49)  # 'I'
	message.append(0x4E)  # 'N'
	message.append(0x52)  # 'R'
	message.append(0x34)  # '4'

	# Message length (2 bytes, little-endian)
	var length = 4 + data.size()  # header + data
	message.append(length & 0xFF)
	message.append((length >> 8) & 0xFF)

	# Command type (1 byte)
	message.append(command_type)

	# Data
	message.append_array(data)

	# Send message
	_socket.put_data(message)

	# Read response
	var response = PackedByteArray()
	var bytes_to_read = 4  # Minimum header

	var status = _socket.get_status()
	if status != StreamPeerTCP.STATUS_CONNECTED:
		return PackedByteArray()

	var available = _socket.get_available_bytes()
	if available >= 4:
		var header = _socket.get_buffer(4)
		if header.size() >= 4:
			# Parse response length
			var resp_len = header[2] | (header[3] << 8)
			bytes_to_read = resp_len

			# Read rest of response
			if available >= resp_len:
				response = _socket.get_buffer(resp_len)

	return response


func _parse_status_response(data: PackedByteArray) -> Dictionary:
	# INRC4 status response format:
	# [0] = status code (0=ok)
	# [1] = mode
	# [2] = e-stop flag
	# [3] = error code
	# [4-7] = temperature (float)
	# [8..] = joint positions (6 floats)

	var result = {
		"mode": 1,
		"e_stop_triggered": false,
		"error_code": 0,
		"controller_temperature": 35.0,
		"joint_positions": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"timestamp": Time.get_datetime_dict_from_system()
	}

	if data.size() < 4:
		return result

	result["mode"] = data[1] if data.size() > 1 else 1
	result["e_stop_triggered"] = data[2] != 0 if data.size() > 2 else false
	result["error_code"] = data[3] if data.size() > 3 else 0

	if data.size() >= 8:
		result["controller_temperature"] = _bytes_to_float(data.slice(4, 8))

	# Joint positions start at byte 8, 6 floats * 4 bytes = 24 bytes
	if data.size() >= 32:
		var positions = []
		for i in range(6):
			positions.append(_bytes_to_float(data.slice(8 + i * 4, 12 + i * 4)))
		result["joint_positions"] = positions
		_joint_positions = positions

	return result


func _get_default_status() -> Dictionary:
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


## ===== Utility =====

func _float_to_bytes(f: float) -> PackedByteArray:
	var bytes = PackedByteArray()
	var int_val = ArrayConv.float_to_bits(f)
	bytes.append(int_val & 0xFF)
	bytes.append((int_val >> 8) & 0xFF)
	bytes.append((int_val >> 16) & 0xFF)
	bytes.append((int_val >> 24) & 0xFF)
	return bytes


func _bytes_to_float(bytes: PackedByteArray) -> float:
	if bytes.size() < 4:
		return 0.0
	var int_val = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)
	return ArrayConv.bits_to_float(int_val)


func _bytes_to_floats(bytes: PackedByteArray) -> Array:
	var floats = []
	for i in range(0, bytes.size() - 3, 4):
		floats.append(_bytes_to_float(bytes.slice(i, i + 4)))
	return floats


func _abort_trajectory_internal() -> void:
	if not is_connected():
		return

	_is_trajectory_running = false
	var response = _send_inrc4_command(INRC4_TRAJECTORY_ABORT, PackedByteArray())


## Internal ArrayConv class for float conversion (GDScript doesn't have built-in)
class ArrayConv:
	static func float_to_bits(f: float) -> int:
		# IEEE 754 single precision
		var sign = 0
		if f < 0:
			sign = 1
			f = -f

		var exp = 0
		var mantissa = f
		while mantissa >= 2.0:
			mantissa /= 2.0
			exp += 1
		while mantissa < 1.0:
			mantissa *= 2.0
			exp -= 1

		exp += 127
		if exp <= 0:
			mantissa = 0
			exp = 0

		mantissa = (mantissa - 1.0) * 8388608.0
		var bits = (sign << 31) | (exp << 23) | int(mantissa)
		return bits

	static func bits_to_float(bits: int) -> float:
		var sign = (bits >> 31) & 1
		var exp = (bits >> 23) & 0xFF
		var mantissa = bits & 0x7FFFFF

		if exp == 0:
			return 0.0

		var f = 1.0 + float(mantissa) / 8388608.0
		exp -= 127
		while exp > 0:
			f *= 2.0
			exp -= 1
		while exp < 0:
			f /= 2.0
			exp += 1

		if sign == 1:
			return -f
		return f