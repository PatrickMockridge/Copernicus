# arm_factory.gd
# A 6-DOF industrial-style arm (base rotation + shoulder/elbow/wrist).

class_name ArmFactory
extends RefCounted


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Arm6"

	# Base pedestal.
	var base := Node3D.new()
	base.name = "base_link"
	root.add_child(base)
	RobotFactory.cylinder(base, "pedestal", 0.16, 0.18, Vector3(0, 0.09, 0), Color(0.4, 0.4, 0.45), "y")

	var chain := [
		["joint_1", Vector3(0, 1, 0), Vector3(0, 0.18, 0), Vector3(0.3, 0.1, 0.3), Color(0.55, 0.55, 0.6)],
		["joint_2", Vector3(0, 0, 1), Vector3(0, 0.23, 0), Vector3(0.12, 0.42, 0.12), Color(0.6, 0.42, 0.25)],
		["joint_3", Vector3(0, 0, 1), Vector3(0, 0.42, 0), Vector3(0.1, 0.34, 0.1), Color(0.6, 0.42, 0.25)],
		["joint_4", Vector3(1, 0, 0), Vector3(0, 0.34, 0), Vector3(0.09, 0.09, 0.09), Color(0.5, 0.5, 0.55)],
		["joint_5", Vector3(0, 0, 1), Vector3(0.09, 0, 0), Vector3(0.08, 0.08, 0.08), Color(0.5, 0.5, 0.55)],
		["joint_6", Vector3(1, 0, 0), Vector3(0.08, 0, 0), Vector3(0.06, 0.06, 0.06), Color(0.5, 0.5, 0.55)],
	]

	var parent: Node3D = base
	for i in range(chain.size()):
		var e: Array = chain[i]
		var j := RobotFactory.joint(parent, e[0], e[1], e[2], -180.0, 180.0)
		var link := Node3D.new()
		link.name = "link_%d" % (i + 1)
		j.add_child(link)
		RobotFactory.box(link, "visual", e[3], Vector3(0, e[3].y * 0.5, 0), e[4])
		parent = link

	# Gripper fingers on the flange.
	RobotFactory.box(parent, "flange", Vector3(0.07, 0.04, 0.07), Vector3(0, 0.02, 0), Color(0.3, 0.3, 0.35))
	var gj := RobotFactory.joint(parent, "gripper_left", Vector3(0, 0, 1), Vector3(0, 0.04, 0.03), -45.0, 45.0)
	RobotFactory.box(gj, "finger", Vector3(0.015, 0.08, 0.02), Vector3(0, 0.04, 0), Color(0.3, 0.3, 0.35))
	var gj2 := RobotFactory.joint(parent, "gripper_right", Vector3(0, 0, 1), Vector3(0, 0.04, -0.03), -45.0, 45.0)
	RobotFactory.box(gj2, "finger", Vector3(0.015, 0.08, 0.02), Vector3(0, 0.04, 0), Color(0.3, 0.3, 0.35))

	# End-effector reference point (gripper tip) — the viewer tracks this for IK reach.
	RobotFactory.sphere(parent, "ee_link", 0.025, Vector3(0, 0.09, 0), Color(0.95, 0.3, 0.3))

	return root
