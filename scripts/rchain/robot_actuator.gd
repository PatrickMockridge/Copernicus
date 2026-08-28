class_name RobotActuator
extends Node
## Drives a wheeled robot (Node3D) from an actuation command and meters the work done.

var _robot: Node3D = null
var _speed: float = 1.0  # units (meters / degrees) per second

signal actuation_finished(work: float)


func setup(robot: Node3D, speed: float = 1.0) -> void:
	_robot = robot
	_speed = speed


## Execute an actuation command and return the measured work.
## Supported: {"action": "drive", "distance": N} (work = N meters) and
##            {"action": "turn",  "angle": N} (work = N degrees).
func actuate(command: Dictionary) -> float:
	var action: String = command.get("action", "drive")
	var work: float = 0.0
	match action:
		"drive":
			work = float(command.get("distance", 0.0))
		"turn":
			work = float(command.get("angle", 0.0))
	_animate(action, work)
	return work


func _animate(action: String, amount: float) -> void:
	if _robot == null or amount <= 0.0:
		return
	var tween := create_tween()
	if action == "turn":
		var target_y := _robot.rotation.y + deg_to_rad(amount)
		tween.tween_property(_robot, "rotation:y", target_y, amount / _speed)
	else:
		var target: Vector3 = _robot.position + _robot.transform.basis * Vector3.FORWARD * amount
		tween.tween_property(_robot, "position", target, amount / _speed)
	tween.tween_callback(func() -> void: actuation_finished.emit(amount))
