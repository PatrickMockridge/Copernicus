# drone_factory.gd
# A quadcopter: body + 4 arms + 4 spinning rotors (about Y).

class_name DroneFactory
extends RefCounted


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "QuadDrone"

	RobotFactory.box(root, "body", Vector3(0.24, 0.05, 0.24), Vector3(0, 0.15, 0), Color(0.15, 0.2, 0.28))

	var arm_dirs: Array[Vector3] = [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]
	var i := 0
	for d in arm_dirs:
		var arm_center := d.normalized() * 0.18
		RobotFactory.box(root, "arm_%d" % (i + 1), Vector3(0.26, 0.02, 0.04), arm_center, Color(0.2, 0.25, 0.33))
		var rotor := RobotFactory.joint(root, "rotor_%d" % (i + 1), Vector3(0, 1, 0), arm_center + d.normalized() * 0.02, -360.0, 360.0)
		RobotFactory.box(rotor, "prop", Vector3(0.02, 0.01, 0.22), Vector3.ZERO, Color(0.7, 0.7, 0.75))
		i += 1

	RobotFactory.cylinder(root, "camera", 0.03, 0.03, Vector3(0, 0.1, 0), Color(0.1, 0.1, 0.12), "y")

	return root
