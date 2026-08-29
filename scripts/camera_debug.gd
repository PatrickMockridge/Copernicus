# camera_debug.gd
# Camera sensor debug visualization
# Visualizes camera frustum as Line3D

class_name CameraDebug
extends Node3D

var _camera: Camera3D
var _robot_node: Node3D
var _frustum_mesh: MeshInstance3D
var _show_frustum: bool = true

var _fov: float = 60.0
var _near: float = 0.1
var _far: float = 10.0
var _aspect: float = 1.33
var _height: float = 0.08  # Sensor height


func _ready() -> void:
	_setup_frustum_mesh()


func _setup_frustum_mesh() -> void:
	_frustum_mesh = MeshInstance3D.new()
	_frustum_mesh.set_name("CameraFrustum")
	add_child(_frustum_mesh)


func set_robot(robot: Node3D) -> void:
	_robot_node = robot


func set_camera(camera: Camera3D) -> void:
	_camera = camera


func set_frustum_params(fov: float, near: float, far: float, aspect: float) -> void:
	_fov = fov
	_near = near
	_far = far
	_aspect = aspect


func set_frustum_visible(visible: bool) -> void:
	_show_frustum = visible
	if _frustum_mesh:
		_frustum_mesh.visible = visible


func update_frustum() -> void:
	if not _frustum_mesh or not _show_frustum:
		return

	_frustum_mesh.mesh = null
	_frustum_mesh.position = Vector3(0, 0.1, 0)

	var lines = PackedVector3Array()

	# Calculate frustum corners at near and far planes
	var half_fov_h = deg_to_rad(_fov / 2.0)
	var half_fov_v = deg_to_rad((_fov / _aspect) / 2.0)

	# Near plane corners
	var near_tl = Vector3(-_height * tan(half_fov_h), _height * tan(half_fov_v), _near)
	var near_tr = Vector3(_height * tan(half_fov_h), _height * tan(half_fov_v), _near)
	var near_bl = Vector3(-_height * tan(half_fov_h), -_height * tan(half_fov_v), _near)
	var near_br = Vector3(_height * tan(half_fov_h), -_height * tan(half_fov_v), _near)

	# Far plane corners
	var far_tl = Vector3(-_height * tan(half_fov_h) * (_far / _near), _height * tan(half_fov_v) * (_far / _near), _far)
	var far_tr = Vector3(_height * tan(half_fov_h) * (_far / _near), _height * tan(half_fov_v) * (_far / _near), _far)
	var far_bl = Vector3(-_height * tan(half_fov_h) * (_far / _near), -_height * tan(half_fov_v) * (_far / _near), _far)
	var far_br = Vector3(_height * tan(half_fov_h) * (_far / _near), -_height * tan(half_fov_v) * (_far / _near), _far)

	# Connect near plane corners
	_add_frustum_line(lines, near_tl, near_tr)
	_add_frustum_line(lines, near_tr, near_br)
	_add_frustum_line(lines, near_br, near_bl)
	_add_frustum_line(lines, near_bl, near_tl)

	# Connect far plane corners
	_add_frustum_line(lines, far_tl, far_tr)
	_add_frustum_line(lines, far_tr, far_br)
	_add_frustum_line(lines, far_br, far_bl)
	_add_frustum_line(lines, far_bl, far_tl)

	# Connect near to far plane
	_add_frustum_line(lines, near_tl, far_tl)
	_add_frustum_line(lines, near_tr, far_tr)
	_add_frustum_line(lines, near_br, far_br)
	_add_frustum_line(lines, near_bl, far_bl)

	# Create ImmediateMesh
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for i in range(0, lines.size(), 2):
		immediate_mesh.surface_add_vertex(lines[i])
		immediate_mesh.surface_add_vertex(lines[i + 1])

	immediate_mesh.surface_end()
	_frustum_mesh.mesh = immediate_mesh

	# Apply material
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.8, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_frustum_mesh.material_override = mat


func _add_frustum_line(lines: PackedVector3Array, from: Vector3, to: Vector3) -> void:
	lines.append(from)
	lines.append(to)
