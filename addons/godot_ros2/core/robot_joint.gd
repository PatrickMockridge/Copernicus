# robot_joint.gd
# Robot joint component

class_name RobotJoint

enum JointType { REVOLUTE, CONTINUOUS, PRISMATIC, FIXED, PLANAR, FLOATING }

var _name: String
var _node: Node3D
var _type: JointType = JointType.REVOLUTE
var _parent_link: String = ""
var _child_link: String = ""
var _axis: Vector3 = Vector3(1, 0, 0)
var _limit_lower: float = -INF
var _limit_upper: float = INF
var _effort_limit: float = INF
var _velocity_limit: float = INF
var _position: float = 0.0
var _velocity: float = 0.0
var _effort: float = 0.0


func _init(name: String) -> void:
	_name = name
	_node = Node3D.new()
	_node.set_name(name)


func _to_string() -> String:
	return "RobotJoint:%s" % _name


func get_name() -> String:
	return _name


func get_node() -> Node3D:
	return _node


func set_type(type: JointType) -> void:
	_type = type


func get_type() -> JointType:
	return _type


func set_parent_link(link: String) -> void:
	_parent_link = link


func get_parent_link() -> String:
	return _parent_link


func get_child_link() -> String:
	return _child_link


func set_child_link(link: String) -> void:
	_child_link = link


func set_axis(axis: Vector3) -> void:
	_axis = axis


func get_axis() -> Vector3:
	return _axis


func set_limits(lower: float, upper: float) -> void:
	_limit_lower = lower
	_limit_upper = upper


func get_limits() -> Dictionary:
	return {"lower": _limit_lower, "upper": _limit_upper}


func set_position(pos: float) -> void:
	_position = pos


func get_position() -> float:
	return _position


func set_velocity(vel: float) -> void:
	_velocity = vel


func get_velocity() -> float:
	return _velocity


func set_effort(eff: float) -> void:
	_effort = eff


func get_effort() -> float:
	return _effort


func physics_update(dt: float) -> void:
	# Apply physics
	pass