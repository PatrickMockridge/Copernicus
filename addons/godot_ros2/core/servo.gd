# servo.gd
# Servo actuator

class_name Servo
extends Actuator

var _angle: float = 0.0
var _target_angle: float = 0.0
var _min_angle: float = -1.57  # -90 degrees
var _max_angle: float = 1.57   # 90 degrees
var _max_speed: float = 3.14    # rad/s


func _init(name: String) -> void:
	super(name)


func set_target_angle(angle: float) -> void:
	_target_angle = clamp(angle, _min_angle, _max_angle)


func set_limits(min_a: float, max_a: float) -> void:
	_min_angle = min_a
	_max_angle = max_a


func physics_update(delta: float) -> void:
	if not _enabled:
		return

	var diff = _target_angle - _angle
	var max_step = _max_speed * delta
	_angle += clamp(diff, -max_step, max_step)


func get_angle() -> float:
	return _angle