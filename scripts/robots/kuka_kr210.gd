class_name KukaKR210
extends Node3D
## Procedural Kuka KR210 6-DOF arm (pick-and-place), built from the Udacity project's
## DH/origin dimensions. Kinematic transform hierarchy — no physics.

const HOME := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const PICK := [0.0, 35.0, -55.0, 0.0, 20.0, 0.0]
const PLACE := [110.0, 15.0, -45.0, 0.0, -10.0, 0.0]

var _joints: Array[Node3D] = []
var _axes: Array[Vector3] = []
var _angles: Array[float] = []
var _names: Array[String] = []
var _fingers: Array[Node3D] = []
var _gripper: Node3D = null
var _cylinder: Node3D = null


func _init() -> void:
	_build()


func _build() -> void:
	var grey := _mat(Color(0.72, 0.72, 0.72))
	var orange := _mat(Color(0.9, 0.5, 0.1))

	# Base pedestal.
	var base := Node3D.new()
	base.name = "base_link"
	add_child(base)
	_add_box(base, Vector3(0.5, 0.33, 0.5), Vector3(0, 0.165, 0), grey)

	# Joint chain: [name, axis, origin, link box size, link box center offset].
	var chain := [
		["joint_1", Vector3(0, 0, 1), Vector3(0, 0, 0.33), Vector3(0.34, 0.22, 0.34), Vector3(0.18, 0.11, 0)],
		["joint_2", Vector3(0, 1, 0), Vector3(0.35, 0, 0.42), Vector3(0.22, 1.25, 0.22), Vector3(0, 0.62, 0)],
		["joint_3", Vector3(0, 1, 0), Vector3(0, 0, 1.25), Vector3(0.18, 0.96, 0.18), Vector3(0, 0.48, 0)],
		["joint_4", Vector3(1, 0, 0), Vector3(0.96, 0, -0.054), Vector3(0.14, 0.14, 0.14), Vector3.ZERO],
		["joint_5", Vector3(0, 1, 0), Vector3(0.54, 0, 0), Vector3(0.12, 0.12, 0.12), Vector3.ZERO],
		["joint_6", Vector3(1, 0, 0), Vector3(0.193, 0, 0), Vector3(0.1, 0.1, 0.1), Vector3.ZERO],
	]

	var parent: Node3D = base
	for i in range(chain.size()):
		var entry: Array = chain[i]
		var jname: String = entry[0]
		var axis: Vector3 = entry[1]
		var origin: Vector3 = entry[2]
		var lsize: Vector3 = entry[3]
		var lcenter: Vector3 = entry[4]

		var joint := Node3D.new()
		joint.name = jname
		joint.position = origin
		parent.add_child(joint)
		_joints.append(joint)
		_axes.append(axis)
		_angles.append(0.0)
		_names.append(jname)

		var link := Node3D.new()
		link.name = "link_%d" % (i + 1)
		joint.add_child(link)
		if lsize != Vector3.ZERO:
			_add_box(link, lsize, lcenter, grey if i < 4 else orange)
		parent = link

	# Gripper + two fingers on the flange (last link).
	_gripper = Node3D.new()
	_gripper.name = "gripper_link"
	parent.add_child(_gripper)
	var palm := _add_box(_gripper, Vector3(0.08, 0.05, 0.1), Vector3(0, 0, 0.05), orange)
	var fl := _add_box(_gripper, Vector3(0.03, 0.08, 0.12), Vector3(-0.05, 0, 0.06), grey)
	var fr := _add_box(_gripper, Vector3(0.03, 0.08, 0.12), Vector3(0.05, 0, 0.06), grey)
	_fingers = [fl, fr]

	# Pick target (cylinder) and drop target (bin) as world-space siblings.
	_cylinder = _add_cylinder(self, 0.045, 0.3, Vector3(1.0, 0.15, 0.35), orange)
	_cylinder.name = "pick_cylinder"
	_add_box(self, Vector3(0.7, 0.05, 0.7), Vector3(-0.7, 0.025, -0.4), grey).name = "bin_floor"
	_add_box(self, Vector3(0.7, 0.25, 0.04), Vector3(-0.7, 0.15, -0.75), grey).name = "bin_wall_n"
	_add_box(self, Vector3(0.7, 0.25, 0.04), Vector3(-0.7, 0.15, -0.05), grey).name = "bin_wall_s"
	_add_box(self, Vector3(0.04, 0.25, 0.7), Vector3(-1.05, 0.15, -0.4), grey).name = "bin_wall_w"
	_add_box(self, Vector3(0.04, 0.25, 0.7), Vector3(-0.35, 0.15, -0.4), grey).name = "bin_wall_e"


## Set all six joint angles (degrees) and return the total travel Σ|Δθ|.
func set_joint_angles(angles: Array) -> float:
	var travel := 0.0
	for i in range(_joints.size()):
		var target: float = float(angles[i]) if i < angles.size() else 0.0
		var delta: float = target - _angles[i]
		travel += abs(delta)
		_angles[i] = target
		_joints[i].rotation = _axes[i] * deg_to_rad(target)
	return travel


## Move the two-finger gripper to an opening half-width (meters).
func set_gripper(half_width: float) -> void:
	if _fingers.size() == 2:
		_fingers[0].position.x = -half_width
		_fingers[1].position.x = half_width


func get_joint_count() -> int:
	return _joints.size()


func get_joint_names() -> Array[String]:
	return _names


func get_joint_axes() -> Array[Vector3]:
	return _axes


func get_joint_angles() -> Array[float]:
	return _angles.duplicate()


func get_joint_nodes() -> Array[Node3D]:
	return _joints


func get_gripper() -> Node3D:
	return _gripper


func get_cylinder() -> Node3D:
	return _cylinder


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


func _add_cylinder(parent: Node3D, radius: float, height: float, center: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CylinderMesh.new()
	mi.mesh.top_radius = radius
	mi.mesh.bottom_radius = radius
	mi.mesh.height = height
	mi.position = center
	mi.material_override = mat
	parent.add_child(mi)
	return mi
