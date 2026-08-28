class_name TurtleBot
extends Node3D
## Simple procedural wheeled robot (box body + four wheels + front direction
## indicator). Kinematic only — the RaaS actuator moves the node directly.

func _init() -> void:
	_build()


func _build() -> void:
	var blue := _mat(Color(0.2, 0.5, 0.9))
	var dark := _mat(Color(0.15, 0.15, 0.15))
	var red := _mat(Color(0.8, 0.2, 0.2))

	# Body.
	_add_box(self, Vector3(1.0, 0.5, 1.6), Vector3.ZERO, blue)

	# Wheels.
	for x in [-0.55, 0.55]:
		for z in [-0.5, 0.5]:
			_add_box(self, Vector3(0.12, 0.35, 0.35), Vector3(x, -0.3, z), dark)

	# Front direction indicator.
	_add_box(self, Vector3(0.1, 0.06, 0.04), Vector3(0, 0.02, -0.82), red)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _add_box(parent: Node3D, size: Vector3, center: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = size
	mi.position = center
	mi.material_override = mat
	parent.add_child(mi)
	return mi
