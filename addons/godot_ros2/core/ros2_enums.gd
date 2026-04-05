# ros2_enums.gd
# ROS 2 enums and constants

class_name ROS2Enum

enum QoSLiveliness {
	UNKNOWN = 0,
	SYSTEM_DEFAULT = 1,
	MANUAL_BY_TOPIC = 2,
}

enum QoSHistory {
	SYSTEM_DEFAULT = 0,
	KEEP_LAST = 1,
	KEEP_ALL = 2,
}

enum QoSDurability {
	VOLATILE = 0,
	TRANSIENT_LOCAL = 1,
	SYSTEM_DEFAULT = 2,
}

enum QoSReliability {
	SYSTEM_DEFAULT = 0,
	BEST_EFFORT = 1,
	RELIABLE = 2,
}

enum QoSReliabilityKind {
	BEST_EFFORT = 1,
	RELIABLE = 2,
}

enum QoSDurabilityKind {
	VOLATILE = 0,
	TRANSIENT_LOCAL = 1,
}

enum QoSLivelinessKind {
	MANUAL_BY_TOPIC = 1,
	SYSTEM_DEFAULT = 2,
	UNKNOWN = 0,
}

enum SubscriptionEventType {
	NEW_MESSAGE = 0,
	DELTA_QOS = 1,
	LIVELINESS_CHANGED = 2,
	REQUESTED_DEADLINE_MISSED = 3,
	REQUESTED_QOS_INCOMPATIBLE = 4,
	SAMPLE_LOST = 5,
}

enum NodeState {
	UNKNOWN = 0,
	NOTSTARTED = 1,
	STARTING = 2,
	RUNNING = 3,
	SHUTTINGDOWN = 4,
	SHUTDOWN = 5,
	FINALIZED = 6,
}

enum ActionGoalResponse {
	ERROR = 0,
	REJECTED = 1,
	ACCEPTED = 2,
}

enum ActionCancelResponse {
	ERROR = 0,
	ACCEPT = 1,
	REJECT = 2,
}

const DEFAULT_HISTORY_DEPTH = 10
const DEFAULT_DURABILITY = QoSDurability.VOLATILE
const DEFAULT_RELIABILITY = QoSReliability.RELIABLE
const DEFAULT_LIVELINESS = QoSLiveliness.SYSTEM_DEFAULT
