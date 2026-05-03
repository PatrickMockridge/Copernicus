# dds_transport.gd
# Fast DDS transport for high-performance pub/sub
# Low-latency communication using DDS directly

class_name DDSTransport
extends RefCounted


## ===== Configuration =====

var _domain_id: int = 0
var _participant_id: int = -1


## ===== Entities =====

var _publishers: Dictionary = {}
var _subscribers: Dictionary = {}


## ===== Signals =====

signal data_received(topic: String, data: Dictionary)
signal connected()
signal disconnected()


## ===== Static Methods =====

static func is_available() -> bool:
	# Check if Fast DDS or cyclonedds is available
	var result = OS.execute("python3", ["-c", "import fastdds; print('available')"], [], true)
	if result == OK:
		return true
	result = OS.execute("python3", ["-c", "import cyclonedds; print('available')"], [], true)
	return result == OK


## ===== Configuration =====

func configure(config: Dictionary) -> void:
	_domain_id = config.get("domain_id", 0)
	_participant_id = config.get("participant_id", -1)


## ===== Publishers =====

## Create a topic publisher
func create_publisher(topic: String, msg_type: String) -> bool:
	# In real implementation, would create DDS topic and data writer
	_publishers[topic] = {
		"msg_type": msg_type,
		"topic": topic
	}
	return true


## Publish data
func publish(topic: String, data: Dictionary) -> void:
	if not _publishers.has(topic):
		return

	# Serialize and send via DDS
	var serialized = JSON.stringify(data)
	_publish_data(topic, serialized)


## ===== Subscribers =====

## Create a topic subscriber
func create_subscriber(topic: String, msg_type: String, callback: Callable) -> bool:
	# In real implementation, would create DDS topic and data reader
	_subscribers[topic] = {
		"msg_type": msg_type,
		"callback": callback,
		"topic": topic
	}
	return true


## ===== Polling =====

## Poll for received data (call in _process)
func poll() -> void:
	for topic in _subscribers:
		var sub = _subscribers[topic]
		var data = _receive_data(topic)
		if data.size() > 0:
			var parsed = JSON.parse_string(data)
			if parsed != null:
				sub["callback"].call(parsed)


## ===== Internal DDS Operations =====

func _publish_data(topic: String, serialized_data: String) -> void:
	# Placeholder for actual DDS write
	# In real impl, would use Fast DDS or Cyclone DDS Python bindings
	pass


func _receive_data(topic: String) -> String:
	# Placeholder for actual DDS read
	# In real impl, would use Fast DDS or Cyclone DDS Python bindings
	return ""


## ===== Topic Management =====

## Get list of available topics
static func list_topics() -> Array:
	# In real implementation, would query DDS for available topics
	return []


## Check if topic exists
func has_topic(topic: String) -> bool:
	return _publishers.has(topic) or _subscribers.has(topic)


## ===== QoS Settings =====

class QosProfile:
	var reliability: int = 1  # 0 = BEST_EFFORT, 1 = RELIABLE
	var durability: int = 0  # 0 = VOLATILE, 1 = TRANSIENT_LOCAL
	var history: int = 1  # 0 = KEEP_LAST, 1 = KEEP_ALL
	var depth: int = 1
	var deadline: float = 0.0
	var lifespan: float = 0.0


func set_qos(topic: String, profile: QosProfile) -> void:
	if _publishers.has(topic):
		_publishers[topic]["qos"] = profile
	if _subscribers.has(topic):
		_subscribers[topic]["qos"] = profile


## ===== Status =====

func get_status() -> Dictionary:
	return {
		"domain_id": _domain_id,
		"publisher_count": _publishers.size(),
		"subscriber_count": _subscribers.size(),
		"topics": _publishers.keys() + _subscribers.keys()
	}