# ros2_node.gd
# ROS 2 Node implementation

class_name ROS2Node

var _node_name: String
var _namespace: String
var _publishers: Dictionary = {}
var _subscriptions: Dictionary = {}
var _service_clients: Dictionary = {}
var _service_servers: Dictionary = {}
var _action_clients: Dictionary = {}
var _action_servers: Dictionary = {}
var _parameters: Dictionary = {}
var _QoS: QoSProfile = QoSProfile.new()
var _bridge_client: ROS2BridgeClient = null


func _init(name: String, ns: String = "") -> void:
	_node_name = name
	_namespace = ns if not ns.is_empty() else "/"


func get_name() -> String:
	return _node_name


func get_namespace() -> String:
	return _namespace


func get_full_name() -> String:
	if _namespace.ends_with("/"):
		return _namespace + _node_name
	return _namespace + "/" + _node_name


func set_QoS(profile: QoSProfile) -> void:
	_QoS = profile


func get_QoS() -> QoSProfile:
	return _QoS


func set_bridge_client(client: ROS2BridgeClient) -> void:
	_bridge_client = client


func get_bridge_client() -> ROS2BridgeClient:
	return _bridge_client


# Publishers
func create_publisher(topic_name: String, message_type: String) -> Publisher:
	var full_topic = _resolve_topic_name(topic_name)
	var publisher = Publisher.new(full_topic, message_type, _QoS)
	if _bridge_client:
		publisher.set_bridge_client(_bridge_client)
	_publishers[full_topic] = publisher
	return publisher


func get_publisher(topic_name: String) -> Publisher:
	return _publishers.get(_resolve_topic_name(topic_name))


func get_publishers() -> Array:
	return _publishers.values()


# Subscriptions
func create_subscription(topic_name: String, message_type: String, callback: Callable) -> Subscription:
	var full_topic = _resolve_topic_name(topic_name)
	var subscription = Subscription.new(full_topic, message_type, callback, _QoS)
	if _bridge_client:
		subscription.set_bridge_client(_bridge_client)
	_subscriptions[full_topic] = subscription
	return subscription


func get_subscription(topic_name: String) -> Subscription:
	return _subscriptions.get(_resolve_topic_name(topic_name))


# Service Clients
func create_client(service_name: String, service_type: String) -> ServiceClient:
	var full_service = _resolve_topic_name(service_name)
	var client = ServiceClient.new(full_service, service_type)
	_service_clients[full_service] = client
	return client


func get_client(service_name: String) -> ServiceClient:
	return _service_clients.get(_resolve_topic_name(service_name))


# Service Servers
func create_service(service_name: String, service_type: String, callback: Callable) -> ServiceServer:
	var full_service = _resolve_topic_name(service_name)
	var server = ServiceServer.new(full_service, service_type, callback)
	_service_servers[full_service] = server
	return server


# Action Clients
func create_action_client(action_name: String, action_type: String) -> ActionClient:
	var full_action = _resolve_topic_name(action_name)
	var client = ActionClient.new(full_action, action_type)
	_action_clients[full_action] = client
	return client


# Action Servers
func create_action_server(action_name: String, action_type: String, execute_callback: Callable) -> ActionServer:
	var full_action = _resolve_topic_name(action_name)
	var server = ActionServer.new(full_action, action_type, execute_callback)
	_action_servers[full_action] = server
	return server


# Parameters
func declare_parameter(name: String, value: Variant) -> void:
	_parameters[name] = value


func set_parameter(name: String, value: Variant) -> bool:
	if name in _parameters:
		_parameters[name] = value
		return true
	return false


func get_parameter(name: String) -> Variant:
	return _parameters.get(name)


# Internal
func _resolve_topic_name(name: String) -> String:
	if name.begins_with("/"):
		return name
	if _namespace.ends_with("/"):
		return _namespace + name
	return _namespace + "/" + name


func get_subscriptions() -> Array:
	return _subscriptions.values()


func get_service_servers() -> Array:
	return _service_servers.values()


func get_action_servers() -> Array:
	return _action_servers.values()
