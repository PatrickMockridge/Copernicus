# robot_factory.gd
# Shared static helpers for building procedural robot models with consistent
# joint metadata (joint_type / joint_axis / limits) that the viewer + joint panel understand.

class_name RobotFactory
extends RefCounted


static func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m


static func box(parent: Node3D, name: String, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = center
	mi.material_override = mat(color)
	parent.add_child(mi)
	return mi


## axis: "x" | "y" | "z" — the cylinder's long axis.
static func cylinder(parent: Node3D, name: String, radius: float, height: float, center: Vector3, color: Color, axis: String = "y") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = center
	mi.material_override = mat(color)
	if axis == "x":
		mi.rotation_degrees = Vector3(0, 0, 90)
	elif axis == "z":
		mi.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, name: String, radius: float, center: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = center
	mi.material_override = mat(color)
	parent.add_child(mi)
	return mi


## Create a revolute joint node with limits metadata.
static func joint(parent: Node3D, name: String, axis: Vector3, origin: Vector3, lower: float = -180.0, upper: float = 180.0) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = origin
	j.set_meta("joint_type", "revolute")
	j.set_meta("joint_axis", axis)
	j.set_meta("has_limits", true)
	j.set_meta("limit_lower", lower)
	j.set_meta("limit_upper", upper)
	parent.add_child(j)
	return j


## Create a prismatic joint node with limits metadata.
static func prismatic(parent: Node3D, name: String, axis: Vector3, origin: Vector3, lower: float = -0.5, upper: float = 0.5) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = origin
	j.set_meta("joint_type", "prismatic")
	j.set_meta("joint_axis", axis)
	j.set_meta("has_limits", true)
	j.set_meta("limit_lower", lower)
	j.set_meta("limit_upper", upper)
	parent.add_child(j)
	return j
