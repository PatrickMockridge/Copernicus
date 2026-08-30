# gizmo.gd
# An axis gizmo shown at the selected node. Translate mode shows X/Y/Z arrows;
# rotate mode shows a yaw ring.

class_name ViewportGizmo
extends Node3D

const MODE_TRANSLATE := 1
const MODE_ROTATE := 2

var _arrows: Node3D
var _ring: MeshInstance3D


func _ready() -> void:
	_arrows = Node3D.new()
	add_child(_arrows)
	_add_axis(_arrows, Vector3.RIGHT, Color.RED)
	_add_axis(_arrows, Vector3.UP, Color.GREEN)
	_add_axis(_arrows, Vector3.BACK, Color.BLUE)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.3
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.flags_unshaded = true
	_ring.material_override = mat
	add_child(_ring)

	visible = false


func set_mode(mode: int) -> void:
	_arrows.visible = (mode == MODE_TRANSLATE)
	_ring.visible = (mode == MODE_ROTATE)


func move_to(p: Vector3) -> void:
	global_position = p


func _add_axis(parent: Node3D, dir: Vector3, color: Color) -> void:
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.height = 0.5
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cyl.mesh = cm
	if dir == Vector3.RIGHT:
		cyl.rotation_degrees = Vector3(0, 0, -90)
	elif dir == Vector3.BACK:
		cyl.rotation_degrees = Vector3(90, 0, 0)
	cyl.position = dir * 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.flags_unshaded = true
	cyl.material_override = mat
	parent.add_child(cyl)
