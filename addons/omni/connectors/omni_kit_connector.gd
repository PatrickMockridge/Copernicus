# omni_kit_connector.gd
# Omniverse Kit connector for live scene synchronization
# Connects to Omniverse Kit via WebSocket for real-time digital twin sync

class_name OmniKitConnector
extends OmniConnector


## ===== Configuration =====

var _kit_version: String = "2023.1"
var _app_name: String = "Copernicus"
var _reconnect_attempts: int = 3
var _reconnect_delay: float = 2.0


## ===== WebSocket =====

var _websocket: WebSocketPeer
var _connection_timeout: float = 10.0
var _connection_start_time: float = 0.0


## ===== Sync State =====

var _pending_updates: Array = []
var _scene_stage_path: String = ""


## ===== Static Methods =====

static func get_connector_name() -> String:
	return "Omniverse Kit"


static func get_connector_description() -> String:
	return "Connect to Omniverse Kit for real-time scene sync, RTX rendering, and digital twin capabilities. Requires NVIDIA GPU + Omniverse Kit installed."


static func is_available() -> bool:
	# Check if WebSocketPeer is available in Godot 4
	# and if Omniverse Kit is installed
	# For now, check WebSocketPeer class exists
	if not ClassDB.class_exists("WebSocketPeer"):
		return false

	# Check if omni package is available (optional)
	var result = OS.execute("python3", ["-c", "import omni; print('available')"], [], true)
	return result == OK


static func get_requirements() -> String:
	return "Requires:\n1. NVIDIA GPU with RTX support\n2. Omniverse Kit installed\n3. Omniverse Connector extension enabled\n4. WS protocol support (port 8210)"



## ===== Connection =====

func connect(uri: String) -> bool:
	if is_connected():
		disconnect()

	_uri = uri if uri else "ws://localhost:8210"
	_connector_type = "OmniKit"

	_websocket = WebSocketPeer.new()
	_connection_start_time = Time.get_ticks_msec() / 1000.0

	var result = _websocket.connect_to_url(_uri)
	if result == OK:
		_set_connection_state(ConnectionState.CONNECTING)
		return true

	push_error("OmniKitConnector: failed to connect to ", _uri)
	return false


func disconnect() -> void:
	if _websocket:
		_websocket.close()
		_websocket = null

	_connected = false
	_set_connection_state(ConnectionState.DISCONNECTED)
	disconnected.emit()


func _set_connection_state(state: ConnectionState) -> void:
	match state:
		ConnectionState.DISCONNECTED:
			_connected = false
			connection_status_changed.emit("disconnected")
		ConnectionState.CONNECTING:
			connection_status_changed.emit("connecting")
		ConnectionState.CONNECTED:
			_connected = true
			connected.emit()
			connection_status_changed.emit("connected")
		ConnectionState.ERROR:
			_connected = false
			error_occurred.emit("Connection error")
			connection_status_changed.emit("error")


## ===== Message Handling =====

func poll() -> void:
	if not _websocket:
		return

	_websocket.poll()

	var state = _websocket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_set_connection_state(ConnectionState.CONNECTED)
			_process_messages()
		WebSocketPeer.STATE_CLOSED:
			_set_connection_state(ConnectionState.DISCONNECTED)

	# Check connection timeout
	if state == WebSocketPeer.STATE_CONNECTING:
		var elapsed = Time.get_ticks_msec() / 1000.0 - _connection_start_time
		if elapsed > _connection_timeout:
			_set_connection_state(ConnectionState.ERROR)


func _process_messages() -> void:
	while _websocket.get_available_packet_count() > 0:
		var packet = _websocket.get_packet()
		_handle_packet(packet)


func _handle_packet(packet: PackedByteArray) -> void:
	var json_str = packet.get_string_from_utf8()
	var message = JSON.parse_string(json_str)

	if message is Dictionary:
		var msg_type = message.get("type", "")

		match msg_type:
			"sync_response":
				_handle_sync_response(message)
			"scene_update":
				_handle_scene_update(message)
			"error":
				error_occurred.emit(message.get("message", "Unknown"))
			_:
				_pass


func _handle_sync_response(response: Dictionary) -> void:
	var success = response.get("success", false)
	if success:
		_last_sync_time = Time.get_ticks_msec() / 1000.0
		scene_synced.emit()
	else:
		error_occurred.emit("Sync failed: " + response.get("error", "Unknown"))


func _handle_scene_update(update: Dictionary) -> void:
	# Apply scene update from Omniverse
	var prim_path = update.get("prim_path", "")
	var property = update.get("property", "")
	var value = update.get("value", null)

	# Emit signal for scene update
	# Caller can connect and handle updates


## ===== Scene Sync =====

func sync_scene(scene: Node3D) -> bool:
	if not is_connected():
		push_error("OmniKitConnector: not connected")
		return false

	# Serialize scene to USD and send
	var sync_data = _serialize_scene_for_sync(scene)
	var message = {
		"type": "sync_scene",
		"payload": sync_data
	}

	return _send_message(message)


func sync_node(node: Node3D) -> bool:
	if not is_connected():
		return false

	var node_data = _serialize_node(node)
	var message = {
		"type": "sync_node",
		"payload": node_data
	}

	return _send_message(message)


func send_transform(node_path: String, transform: Transform3D) -> bool:
	if not is_connected():
		return false

	var transform_data = godot_transform_to_list(transform)
	var message = {
		"type": "transform_update",
		"prim_path": node_path,
		"transform": transform_data
	}

	return _send_message(message)


func send_material(material_path: String, material_data: Dictionary) -> bool:
	if not is_connected() or not _sync_materials:
		return true

	var message = {
		"type": "material_update",
		"material_path": material_path,
		"data": material_data
	}

	return _send_message(message)


func send_mesh(mesh_path: String, mesh_data: Dictionary) -> bool:
	if not is_connected() or not _sync_meshes:
		return true

	var message = {
		"type": "mesh_update",
		"mesh_path": mesh_path,
		"data": mesh_data
	}

	return _send_message(message)


## ===== Serialization =====

func _serialize_scene_for_sync(scene: Node3D) -> Dictionary:
	var scene_data = {
		"root": scene.name,
		"nodes": []
	}

	for child in scene.get_children():
		if child is Node3D:
			scene_data["nodes"].append(_serialize_node(child))

	return scene_data


func _serialize_node(node: Node3D) -> Dictionary:
	var data = {
		"name": node.name,
		"type": _get_node_type_string(node),
		"path": node.get_path(),
		"transform": godot_transform_to_list(node.transform)
	}

	if node.has_method("get_mesh"):
		var mesh = node.get_mesh()
		if mesh:
			data["mesh"] = _serialize_mesh(mesh)

	if node is MeshInstance3D and node.mesh:
		data["mesh_data"] = _serialize_mesh(node.mesh)

	return data


func _serialize_mesh(mesh: ArrayMesh) -> Dictionary:
	var mesh_data = {
		"vertices": [],
		"indices": []
	}

	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if arrays.size() > 0 and arrays[0] is PackedVector3Array:
			var verts = arrays[0]
			for v in verts:
				mesh_data["vertices"].append([v.x, v.y, v.z])

		if arrays.size() > 12 and arrays[12] is PackedInt32Array:
			var idx = arrays[12]
			for i in idx:
				mesh_data["indices"].append(int(i))

	return mesh_data


func _get_node_type_string(node: Node) -> String:
	if node is MeshInstance3D:
		return "Mesh"
	if node is Camera3D:
		return "Camera"
	if node is DirectionalLight3D:
		return "DistantLight"
	if node is OmniLight3D:
		return "SphereLight"
	if node is SpotLight3D:
		return "SpotLight"
	return "Xform"


## ===== Message Sending =====

func _send_message(message: Dictionary) -> bool:
	if not is_connected():
		return false

	var json_str = JSON.stringify(message)
	var packet = json_str.to_utf8_buffer()

	var result = _websocket.send_text(json_str)
	return result == OK


## ===== Connection State Enum =====

enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	ERROR
}


## ===== Auto-Sync Process =====

var _sync_timer: float = 0.0


func _process(delta: float) -> void:
	if not _connected:
		return

	poll()

	if _auto_sync:
		_sync_timer += delta
		if _sync_timer >= _sync_interval:
			_sync_timer = 0.0
			_sync_tracked_nodes()


func _sync_tracked_nodes() -> void:
	for node in _tracked_nodes.values():
		if node is Node3D and is_instance_valid(node):
			sync_node(node)


## ===== Receive Updates =====

func receive_updates() -> void:
	poll()

	# Process any pending updates from Omniverse
	while _pending_updates.size() > 0:
		var update = _pending_updates.pop_front()
		_handle_scene_update(update)


func _queue_update(update: Dictionary) -> void:
	_pending_updates.append(update)


## ===== Status =====

func get_status() -> Dictionary:
	var status = super.get_status()
	if _websocket:
		status["ws_state"] = _websocket.get_ready_state()
	status["kit_version"] = _kit_version
	status["app_name"] = _app_name
	return status


## ===== Reconnection =====

func reconnect() -> bool:
	var attempts = 0
	while attempts < _reconnect_attempts:
		disconnect()
		await get_tree().create_timer(_reconnect_delay).timeout

		if connect(_uri):
			return true

		attempts += 1

	return false