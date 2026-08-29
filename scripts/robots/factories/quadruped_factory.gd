# quadruped_factory.gd
# A four-legged robot: body + 4 legs, each hip (about X) + knee (about X).

class_name QuadrupedFactory
extends RefCounted


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Quadruped"

	var body := Node3D.new()
	body.name = "base_link"
	root.add_child(body)
	RobotFactory.box(body, "body", Vector3(0.5, 0.12, 0.3), Vector3(0, 0.3, 0), Color(0.25, 0.45, 0.7))

	var legs := [
		[Vector3(0.2, 0.3, 0.12), 1.0],
		[Vector3(-0.2, 0.3, 0.12), 1.0],
		[Vector3(0.2, 0.3, -0.12), 1.0],
		[Vector3(-0.2, 0.3, -0.12), 1.0],
	]
	var i := 0
	for leg in legs:
		var origin: Vector3 = leg[0]
		var hip := RobotFactory.joint(body, "hip_%d" % (i + 1), Vector3(1, 0, 0), origin, -60.0, 60.0)
		RobotFactory.box(hip, "thigh", Vector3(0.04, 0.22, 0.04), Vector3(0, -0.11, 0), Color(0.3, 0.35, 0.4))
		var knee := RobotFactory.joint(hip, "knee_%d" % (i + 1), Vector3(1, 0, 0), Vector3(0, -0.22, 0), -120.0, 0.0)
		RobotFactory.box(knee, "shin", Vector3(0.035, 0.2, 0.035), Vector3(0, -0.1, 0), Color(0.35, 0.4, 0.45))
		RobotFactory.box(knee, "foot", Vector3(0.05, 0.03, 0.06), Vector3(0, -0.2, 0), Color(0.15, 0.15, 0.18))
		i += 1

	return root
