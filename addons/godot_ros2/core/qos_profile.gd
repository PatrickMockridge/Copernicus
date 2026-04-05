# qos_profile.gd
# QoS Profile for ROS 2

class_name QoSProfile

var history: int = ROS2Enum.QoSHistory.KEEP_LAST
var depth: int = 10
var durability: int = ROS2Enum.QoSDurability.VOLATILE
var reliability: int = ROS2Enum.QoSReliability.RELIABLE
var liveliness: int = ROS2Enum.QoSLiveliness.SYSTEM_DEFAULT
var liveliness_lease_duration: float = -1.0
var deadline: float = -1.0
var lifespan: float = -1.0

# Avoid redesign (for compatibility)
var avoid_ros_namespace_conventions: bool = false


func _init(
	h: int = ROS2Enum.QoSHistory.KEEP_LAST,
	d: int = 10,
	dur: int = ROS2Enum.QoSDurability.VOLATILE,
	rel: int = ROS2Enum.QoSReliability.RELIABLE
) -> void:
	history = h
	depth = d
	durability = dur
	reliability = rel


static func best_effort() -> QoSProfile:
	var profile = QoSProfile.new()
	profile.reliability = ROS2Enum.QoSReliability.BEST_EFFORT
	return profile


static func reliable() -> QoSProfile:
	var profile = QoSProfile.new()
	profile.reliability = ROS2Enum.QoSReliability.RELIABLE
	return profile


static func transient_local() -> QoSProfile:
	var profile = QoSProfile.new()
	profile.durability = ROS2Enum.QoSDurability.TRANSIENT_LOCAL
	return profile


static func keep_last(depth: int = 10) -> QoSProfile:
	var profile = QoSProfile.new()
	profile.history = ROS2Enum.QoSHistory.KEEP_LAST
	profile.depth = depth
	return profile


static func keep_all() -> QoSProfile:
	var profile = QoSProfile.new()
	profile.history = ROS2Enum.QoSHistory.KEEP_ALL
	return profile


static func sensor_data() -> QoSProfile:
	var profile = QoSProfile.new()
	profile.history = ROS2Enum.QoSHistory.KEEP_LAST
	profile.depth = 5
	profile.reliability = ROS2Enum.QoSReliability.BEST_EFFORT
	profile.durability = ROS2Enum.QoSDurability.VOLATILE
	return profile


static func parameter() -> QoSProfile:
	var profile = QoSProfile.new()
	profile.history = ROS2Enum.QoSHistory.KEEP_LAST
	profile.depth = 1000
	profile.reliability = ROS2Enum.QoSReliability.RELIABLE
	profile.durability = ROS2Enum.QoSDurability.TRANSIENT_LOCAL
	return profile


static func services() -> QoSProfile:
	var profile = QoSProfile.new()
	profile.history = ROS2Enum.QoSHistory.KEEP_LAST
	profile.depth = 10
	profile.reliability = ROS2Enum.QoSReliability.RELIABLE
	profile.durability = ROS2Enum.QoSDurability.VOLATILE
	return profile


static func action() -> QoSProfile:
	var profile = QoSProfile.new()
	profile.history = ROS2Enum.QoSHistory.KEEP_LAST
	profile.depth = 10
	profile.reliability = ROS2Enum.QoSReliability.RELIABLE
	profile.durability = ROS2Enum.QoSDurability.TRANSIENT_LOCAL
	return profile


func to_dictionary() -> Dictionary:
	return {
		"history": history,
		"depth": depth,
		"durability": durability,
		"reliability": reliability,
		"liveliness": liveliness,
		"liveliness_lease_duration": liveliness_lease_duration,
		"deadline": deadline,
		"lifespan": lifespan,
		"avoid_ros_namespace_conventions": avoid_ros_namespace_conventions
	}
