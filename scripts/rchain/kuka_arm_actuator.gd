class_name KukaArmActuator
extends Node
## Drives a KukaKR210 arm through RaaS actuation commands and meters the work
## (joint travel in degrees).

var _arm: KukaKR210 = null

signal actuation_finished(work: float)


func setup(arm: KukaKR210) -> void:
	_arm = arm


## Execute an actuation command and return the measured work (degrees of joint travel).
## {"action":"move_joints","joints":[...]} or {"action":"pick_and_place"}.
func actuate(command: Dictionary) -> float:
	match command.get("action", "move_joints"):
		"move_joints":
			var work := _arm.set_joint_angles(command.get("joints", []))
			actuation_finished.emit(work)
			return work
		"pick_and_place":
			var work := _pick_and_place_work()
			_animate_sequence()
			return work
	return 0.0


## Fixed total joint travel of the pick-and-place sequence (degrees).
func _pick_and_place_work() -> float:
	var poses := [KukaKR210.HOME, KukaKR210.PICK, KukaKR210.PLACE, KukaKR210.HOME]
	var work := 0.0
	var prev: Array = KukaKR210.HOME
	for i in range(1, poses.size()):
		var pose: Array = poses[i]
		for j in range(prev.size()):
			work += abs(float(pose[j]) - float(prev[j]))
		prev = pose
	return work


func _animate_sequence() -> void:
	if _arm == null:
		return
	var tween := create_tween()
	_tween_to(tween, KukaKR210.PICK, 1.0)
	tween.tween_callback(func() -> void: _arm.set_gripper(0.03))  # grasp
	tween.tween_interval(0.3)
	_tween_to(tween, KukaKR210.PLACE, 1.0)
	tween.tween_callback(func() -> void: _arm.set_gripper(0.09))  # release
	tween.tween_interval(0.3)
	_tween_to(tween, KukaKR210.HOME, 1.0)


func _tween_to(tween: Tween, target: Array, duration: float) -> void:
	for i in range(_arm.get_joint_count()):
		var rot: Vector3 = _arm.get_joint_axes()[i] * deg_to_rad(float(target[i]))
		tween.parallel().tween_property(_arm.get_joint_nodes()[i], "rotation", rot, duration)
