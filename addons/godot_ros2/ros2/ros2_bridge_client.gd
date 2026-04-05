# ros2_bridge_client.gd
# TCP/UDP client for communicating with the Godot-ROS2 bridge

class_name ROS2BridgeClient

const TCP_PORT = 8765
const UDP_PORT = 8766

var _tcp_socket: StreamPeerTCP = null
var _udp_socket: PacketPeerUDP = null
var _connected: bool = false
var _host: String = "127.0.0.1"
var _last_error: String = ""

# Message queues for subscriptions
var _subscription_queues: Dictionary = {}


func _init(remote_host: String = "127.0.0.1") -> void:
	_host = remote_host


async func connect_bridge() -> bool:
	"""Connect to the ROS2 bridge via TCP and UDP."""
	_connected = false

	# Connect TCP
	_tcp_socket = StreamPeerTCP.new()
	_tcp_socket.connect_to_host(_host, TCP_PORT)

	# Wait for connection with timeout
	var timeout = 5.0
	var elapsed = 0.0
	while elapsed < timeout:
		if _tcp_socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		elapsed += 0.1
		await Engine.get_main_loop().process_frame

	if _tcp_socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_last_error = "TCP connection timeout"
		return false

	# Setup UDP
	_udp_socket = PacketPeerUDP.new()
	_udp_socket.set_dest_address(_host, UDP_PORT)

	_connected = true
	return true


func disconnect_bridge() -> void:
	"""Disconnect from the bridge."""
	if _tcp_socket:
		_tcp_socket.disconnect_from_host()
		_tcp_socket = null
	if _udp_socket:
		_udp_socket.close()
		_udp_socket = null
	_connected = false


func is_bridge_connected() -> bool:
	return _connected


func get_last_error() -> String:
	return _last_error


# TCP Commands
func send_command(cmd: Dictionary) -> Dictionary:
	"""Send a command over TCP and return the response."""
	if not _connected or not _tcp_socket:
		return {"status": "error", "message": "Not connected"}

	var json_str = JSON.stringify(cmd)
	_tcp_socket.put_line(json_str)

	# Read response
	var response_line = _tcp_socket.get_line()
	if response_line.is_empty():
		return {"status": "error", "message": "Empty response"}

	var json = JSON.new()
	var parse_result = json.parse(response_line)
	if parse_result != OK:
		return {"status": "error", "message": "Failed to parse response"}

	return json.get_data()


func create_publisher(topic: String, msg_type: String, qos: int = 10) -> bool:
	"""Create a publisher on the bridge."""
	var response = send_command({
		"cmd": "create_pub",
		"topic": topic,
		"type": msg_type,
		"qos": qos
	})
	return response.get("status") == "ok"


func create_subscription(topic: String, msg_type: String, qos: int = 10) -> bool:
	"""Create a subscription on the bridge."""
	var response = send_command({
		"cmd": "create_sub",
		"topic": topic,
		"type": msg_type,
		"qos": qos
	})
	if response.get("status") == "ok":
		_subscription_queues[topic] = []
		return true
	return false


func destroy_publisher(topic: String) -> bool:
	"""Destroy a publisher on the bridge."""
	var response = send_command({"cmd": "destroy_pub", "topic": topic})
	return response.get("status") == "ok"


func destroy_subscription(topic: String) -> bool:
	"""Destroy a subscription on the bridge."""
	var response = send_command({"cmd": "destroy_sub", "topic": topic})
	if response.get("status") == "ok":
		_subscription_queues.erase(topic)
		return true
	return false


func spin() -> void:
	"""Process ROS2 callbacks."""
	send_command({"cmd": "spin"})


# UDP Data
func publish_udp(topic: String, data: Dictionary) -> bool:
	"""Publish a message over UDP."""
	if not _connected or not _udp_socket:
		return false

	var msg: Dictionary = {
		"topic": topic,
		"data": data,
		"ts": Time.get_ticks_msec()
	}

	var json_str = JSON.stringify(msg)
	var packet: PackedByteArray = json_str.to_utf8_buffer()
	var result = _udp_socket.put_packet(packet)
	return result == OK


func receive_messages() -> Dictionary:
	"""Receive pending messages from UDP and queue them."""
	if not _connected or not _udp_socket:
		return {}

	var messages: Dictionary = {}

	# Poll UDP
	while _udp_socket.get_available_packet_count() > 0:
		var packet = _udp_socket.get_packet()
		var json_str = packet.get_string_from_utf8()
		var json = JSON.new()
		if json.parse(json_str) == OK:
			var msg = json.get_data()
			var topic = msg.get("topic")
			if topic:
				if not _subscription_queues.has(topic):
					_subscription_queues[topic] = []
				_subscription_queues[topic].append(msg.get("data"))

	# Populate messages dictionary with latest per topic
	for topic in _subscription_queues:
		var queue = _subscription_queues[topic]
		if not queue.is_empty():
			messages[topic] = queue.pop_front()

	return messages


func get_queued_messages(topic: String) -> Array:
	"""Get all queued messages for a topic."""
	return _subscription_queues.get(topic, [])


func has_message(topic: String) -> bool:
	"""Check if there are messages queued for a topic."""
	var queue = _subscription_queues.get(topic)
	return queue != null and not queue.is_empty()


func pop_message(topic: String) -> Dictionary:
	"""Pop the next message for a topic."""
	var queue = _subscription_queues.get(topic)
	if queue and not queue.is_empty():
		return queue.pop_front()
	return {}