# sensor.gd
# Base sensor class

class_name Sensor

var _name: String
var _robot: Node3D
var _parent_node: Node3D
var _update_rate: float = 30.0
var _last_update: float = 0.0
var _enabled: bool = true
var _frame_id: String = ""
var _pose: Transform3D = Transform3D.IDENTITY
var _noise_enabled: bool = false
var _noise_params: Dictionary = {}


func _init(name: String) -> void:
	_name = name
	_parent_node = Node3D.new()
	_parent_node.set_name(name)


func _to_string() -> String:
	return "Sensor:%s" % _name


func get_name() -> String:
	return _name


func get_node() -> Node3D:
	return _parent_node


func set_robot(robot: Node3D) -> void:
	_robot = robot


func get_robot() -> Node3D:
	return _robot


func set_frame_id(frame: String) -> void:
	_frame_id = frame


func get_frame_id() -> String:
	return _frame_id


func set_update_rate(rate: float) -> void:
	_update_rate = rate


func get_update_rate() -> float:
	return _update_rate


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_enabled() -> bool:
	return _enabled


func set_pose(pose: Transform3D) -> void:
	_pose = pose
	_parent_node.set_transform(pose)


func get_pose() -> Transform3D:
	return _pose


func set_noise_enabled(enabled: bool) -> void:
	_noise_enabled = enabled


func configure(params: Dictionary) -> void:
	if "update_rate" in params:
		set_update_rate(params["update_rate"])
	if "frame_id" in params:
		set_frame_id(params["frame_id"])
	if "pose" in params:
		set_pose(params["pose"])
	if "noise" in params:
		_noise_enabled = true
		_noise_params = params["noise"]


func should_update(current_time: float) -> bool:
	if not _enabled:
		return false
	var period = 1.0 / _update_rate
	return (current_time - _last_update) >= period


func mark_updated(current_time: float) -> void:
	_last_update = current_time


func get_header() -> Dictionary:
	return StdMsgs.create_header_now(_frame_id if not _frame_id.is_empty() else _name)


func apply_noise(value: float, param_name: String) -> float:
	if not _noise_enabled:
		return value
	var mean = _noise_params.get(param_name + "_mean", 0.0)
	var stddev = _noise_params.get(param_name + "_stddev", 0.0)
	return value + randfn(mean, stddev)