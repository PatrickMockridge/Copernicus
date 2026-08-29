# gripper_factory.gd
# A two-finger parallel gripper on a wrist mount.

class_name GripperFactory
extends RefCounted


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Gripper"

	RobotFactory.cylinder(root, "wrist", 0.05, 0.12, Vector3(0, 0.18, 0), Color(0.4, 0.4, 0.45), "y")
	RobotFactory.box(root, "palm", Vector3(0.16, 0.06, 0.1), Vector3(0, 0.12, 0), Color(0.5, 0.5, 0.55))

	# Two fingers slide along X to open/close (prismatic).
	var lf := RobotFactory.prismatic(root, "finger_left", Vector3(1, 0, 0), Vector3(-0.06, 0.08, 0), -0.06, 0.02)
	RobotFactory.box(lf, "finger", Vector3(0.02, 0.12, 0.03), Vector3(0, -0.06, 0), Color(0.6, 0.42, 0.25))
	var rf := RobotFactory.prismatic(root, "finger_right", Vector3(1, 0, 0), Vector3(0.06, 0.08, 0), -0.02, 0.06)
	RobotFactory.box(rf, "finger", Vector3(0.02, 0.12, 0.03), Vector3(0, -0.06, 0), Color(0.6, 0.42, 0.25))

	return root
