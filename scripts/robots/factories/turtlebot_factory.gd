# turtlebot_factory.gd
# Grounded differential-drive mobile base (2 drive wheels about the X axle).

class_name TurtleBotFactory
extends RefCounted

const AXLE := Vector3(1, 0, 0)  # wheels roll about the left-right axis


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "TurtleBot4"

	var body := RobotFactory.box(root, "base_link", Vector3(0.3, 0.1, 0.2), Vector3(0, 0.05, 0), Color(0.2, 0.55, 0.3))
	body.name = "base_link"

	for side in [-1.0, 1.0]:
		var wj := RobotFactory.joint(root, "wheel_%s_joint" % ("l" if side < 0 else "r"), AXLE, Vector3(0.12 * side, 0.04, 0.0), -360.0, 360.0)
		RobotFactory.cylinder(wj, "wheel", 0.04, 0.02, Vector3.ZERO, Color(0.1, 0.1, 0.12), "x")

	RobotFactory.box(root, "sensor_mount", Vector3(0.08, 0.06, 0.08), Vector3(0.08, 0.13, 0.0), Color(0.12, 0.12, 0.14))

	return root
