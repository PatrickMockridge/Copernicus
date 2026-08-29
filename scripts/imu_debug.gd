# imu_debug.gd
# IMU sensor debug visualization
# Visualizes IMU axes as colored arrows

class_name ImuDebug
extends Node3D

var _x_axis: MeshInstance3D
var _y_axis: MeshInstance3D
var _z_axis: MeshInstance3D
var _robot_node: Node3D
var _show_axes: bool = true

var _axis_length: float = 0.15
var _axis_radius: float = 0.003


func _ready() -> void:
	_setup_axes()


func _setup_axes() -> void:
	# X axis (red) - forward
	_x_axis = _create_axis("XAxis", Color(1.0, 0.2, 0.2), Vector3.RIGHT)
	# Y axis (green) - up
	_y_axis = _create_axis("YAxis", Color(0.2, 1.0, 0.2), Vector3.UP)
	# Z axis (blue) - left
	_z_axis = _create_axis("ZAxis", Color(0.2, 0.2, 1.0), Vector3.BACK)


func _create_axis(name: String, color: Color, direction: Vector3) -> MeshInstance3D:
	var axis = MeshInstance3D.new()
	axis.set_name(name)

	# Create cylinder
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = _axis_radius
	cylinder.bottom_radius = _axis_radius
	cylinder.height = _axis_length
	axis.mesh = cylinder

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	axis.material_override = mat

	# Add to tree before orienting (look_at requires the node to be in the tree).
	add_child(axis)
	axis.position = direction * (_axis_length / 2.0)
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	axis.look_at(axis.position + direction, up)
	axis.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	return axis


func set_robot(robot: Node3D) -> void:
	_robot_node = robot
	if robot:
		position = robot.position


func set_axes_visible(visible: bool) -> void:
	_show_axes = visible
	if _x_axis:
		_x_axis.visible = visible
	if _y_axis:
		_y_axis.visible = visible
	if _z_axis:
		_z_axis.visible = visible


func update_from_imu(orientation: Quaternion) -> void:
	# Update axis orientation based on IMU orientation
	if _x_axis:
		_x_axis.quaternion = orientation * Quaternion(Vector3.RIGHT, 0)
	if _y_axis:
		_y_axis.quaternion = orientation * Quaternion(Vector3.UP, 0)
	if _z_axis:
		_z_axis.quaternion = orientation * Quaternion(Vector3.BACK, 0)
