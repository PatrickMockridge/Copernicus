# joint_controller.gd
# Joint controller component

class_name JointController

var _joint: RobotJoint
var _target_position: float = 0.0
var _target_velocity: float = 0.0
var _target_effort: float = 0.0
var _Kp: float = 1.0
var _Ki: float = 0.0
var _Kd: float = 0.0
var _integral: float = 0.0
var _last_error: float = 0.0


func _init(name: String = "") -> void:
	pass


func set_joint(joint: RobotJoint) -> void:
	_joint = joint


func set_target_position(pos: float) -> void:
	_target_position = pos


func set_target_velocity(vel: float) -> void:
	_target_velocity = vel


func set_target_effort(eff: float) -> void:
	_target_effort = eff


func set_gains(kp: float, ki: float, kd: float) -> void:
	_Kp = kp
	_Ki = ki
	_Kd = kd


func update(dt: float) -> void:
	if not _joint:
		return

	var error = _target_position - _joint.get_position()
	_integral += error * dt
	var derivative = (error - _last_error) / dt if dt > 0 else 0.0
	_last_error = error

	var effort = _Kp * error + _Ki * _integral + _Kd * derivative
	_joint.set_effort(min(effort, _joint._effort_limit))