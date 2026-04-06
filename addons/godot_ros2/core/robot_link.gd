# robot_link.gd
# Robot link component

class_name RobotLink

var _name: String
var _node: Node3D
var _mass: float = 1.0
var _inertia: Vector3 = Vector3.ONE
var _parent_joint: String = ""
var _is_root: bool = false
var _visual_mesh: Node3D
var _collision_shape: Shape3D


func _init(name: String) -> void:
	_name = name
	_node = Node3D.new()
	_node.set_name(name)


func _to_string() -> String:
	return "RobotLink:%s" % _name


func get_name() -> String:
	return _name


func get_node() -> Node3D:
	return _node


func set_mass(m: float) -> void:
	_mass = m


func get_mass() -> float:
	return _mass


func set_inertia(i: Vector3) -> void:
	_inertia = i


func get_inertia() -> Vector3:
	return _inertia


func set_parent_joint(joint_name: String) -> void:
	_parent_joint = joint_name


func get_parent_joint() -> String:
	return _parent_joint


func set_root(is_root: bool) -> void:
	_is_root = is_root


func is_root() -> bool:
	return _is_root


func set_visual_mesh(mesh: Node3D) -> void:
	if _visual_mesh and _node.has_child(_visual_mesh):
		_node.remove_child(_visual_mesh)
	_visual_mesh = mesh
	if _visual_mesh:
		_node.add_child(_visual_mesh)


func get_visual_mesh() -> Node3D:
	return _visual_mesh


func set_collision_shape(shape: Shape3D) -> void:
	_collision_shape = shape


func get_collision_shape() -> Shape3D:
	return _collision_shape