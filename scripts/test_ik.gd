# test_ik.gd
# Headless test for the arm IK reach feature: load Arm6, solve to a target, and
# assert the end-effector converges. Run:
#   godot --headless --script res://scripts/test_ik.gd

extends SceneTree

var _fails := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true

	var viewer := RobotViewerController.new()
	root.add_child(viewer)
	var arm := ArmFactory.build()
	viewer.load_robot_node(arm)

	_ok(viewer.get_end_effector_position() != Vector3.ZERO, "end-effector found")

	var target := Vector3(0.35, 0.5, 0.3)
	viewer.set_target_position(target)
	var before: float = viewer.get_end_effector_position().distance_to(target)
	viewer.solve_ik_to_target()
	var after: float = viewer.get_end_effector_position().distance_to(target)

	print("  IK distance: %.3f -> %.3f" % [before, after])
	_ok(after < 0.05, "end-effector reaches target (within 5cm)")
	_ok(after < before, "IK reduced the distance")

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)
	return true


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
