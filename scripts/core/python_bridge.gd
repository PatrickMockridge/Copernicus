# python_bridge.gd
# Persistent Python subprocess bridge via local TCP socket.
# Eliminates ~200ms per-call overhead from temp-file IPC.
# Same StreamPeerTCP pattern used by ros2_bridge_client.gd.

class_name PythonBridge
extends RefCounted

signal bridge_ready()
signal bridge_error(message: String)

var _pid: int = -1
var _port: int = 0
var _socket: StreamPeerTCP
var _connected: bool = false
var _next_id: int = 0
var _pending: Dictionary = {}
var _buffer: String = ""


func start(script_path: String, port: int = 9876, extra_args: Array = []) -> bool:
	_port = port
	var args = ["-u", script_path, "--tcp", "--port", str(port)]
	args.append_array(extra_args)
	_pid = OS.create_process("python3", args)
	if _pid == -1:
		bridge_error.emit("Failed to create Python process")
		return false

	# Wait a moment for the server to start
	var start_ticks = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ticks < 3000:
		OS.delay_msec(100)
		if _try_connect():
			_connected = true
			bridge_ready.emit()
			return true

	bridge_error.emit("TCP connection timeout")
	return false


func _try_connect() -> bool:
	_socket = StreamPeerTCP.new()
	_socket.connect_to_host("127.0.0.1", _port)

	var start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 2000:
		_socket.poll()
		match _socket.get_status():
			StreamPeerTCP.STATUS_CONNECTED:
				return true
			StreamPeerTCP.STATUS_ERROR:
				return false
		OS.delay_msec(10)
	return false


func send(cmd: Dictionary) -> Dictionary:
	if not _connected:
		return {"status": "error", "message": "Not connected"}

	var id = _next_id
	_next_id += 1
	cmd["_id"] = id

	var json_str = JSON.stringify(cmd) + "\n"
	var err = _socket.put_data(json_str.to_utf8_buffer())
	if err != OK:
		return {"status": "error", "message": "Send failed"}

	# Read response line
	var result = _read_response()
	if result.is_empty():
		return {"status": "error", "message": "Empty response"}
	return result


func _read_response() -> Dictionary:
	# Read until we get a complete line
	var start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 5000:
		_socket.poll()
		match _socket.get_status():
			StreamPeerTCP.STATUS_CONNECTED:
				var available = _socket.get_available_bytes()
				if available > 0:
					var data = _socket.get_data(available)
					if data[0] == OK:
						_buffer += data[1].get_string_from_utf8()
						if "\n" in _buffer:
							var parts = _buffer.split("\n", true, 1)
							var line = parts[0]
							_buffer = parts[1] if parts.size() > 1 else ""
							var parsed = JSON.parse_string(line)
							if parsed is Dictionary:
								return parsed
				else:
					OS.delay_msec(5)
			StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE:
				return {}
		OS.delay_msec(5)
	return {}


func is_bridge_connected() -> bool:
	return _connected


func shutdown() -> void:
	if _connected:
		send({"cmd": "shutdown"})
		_connected = false
	if _socket:
		_socket.disconnect_from_host()
		_socket = null
	if _pid > 0:
		OS.kill(_pid)
		_pid = -1
	_buffer = ""
