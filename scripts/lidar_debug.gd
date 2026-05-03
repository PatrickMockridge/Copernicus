# lidar_debug.gd
# LIDAR sensor debug visualization
# Visualizes LIDAR rays as Line3D or ImmediateMesh

class_name LidarDebug
extends Node3D

signal scan_completed(distances: Array)

var _ray_count: int = 360
var _max_range: float = 10.0
var _angle_min: float = 0.0
var _angle_max: float = 2.0 * PI
var _increments: float

var _robot_node: Node3D
var _origin_offset: Vector3 = Vector3(0, 0.1, 0)

var _line_multimesh: MultiMesh
var _multimesh_instance: MultiMeshInstance3D
var _debug_lines: bool = true


func _ready() -> void:
	_increments = (_angle_max - _angle_min) / _ray_count if _ray_count > 0 else 0
	_setup_debug_visuals()


func _setup_debug_visuals() -> void:
	# Create multimesh for efficient line rendering
	_line_multimesh = MultiMesh.new()
	_line_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_line_multimesh.use_colors = true

	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.005, 0.005, 0.1)
	_line_multimesh.mesh = box_mesh

	_line_multimesh.instance_count = _ray_count

	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.multimesh = _line_multimesh
	_multimesh_instance.set_name("LidarRays")
	add_child(_multimesh_instance)


func set_robot(robot: Node3D) -> void:
	_robot_node = robot


func set_ray_count(count: int) -> void:
	_ray_count = count
	_increments = (_angle_max - _angle_min) / _ray_count if _ray_count > 0 else 0
	if _line_multimesh:
		_line_multimesh.instance_count = _ray_count


func set_max_range(range: float) -> void:
	_max_range = range


func scan() -> Array:
	var distances: Array = []
	if not _robot_node:
		return distances

	var space_state = get_world_3d().direct_space_state
	var origin = _robot_node.global_transform.origin + _origin_offset

	for i in range(_ray_count):
		var angle = _angle_min + (i * _increments)
		var direction = Vector3(
			cos(angle),
			0,
			sin(angle)
		)

		var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * _max_range)
		query.collide_with_bodies = true
		query.collide_with_areas = false

		var result = space_state.intersect_ray(query)
		var distance = _max_range if not result else result.position.distance_to(origin)
		distances.append(distance)

		_update_ray_visual(i, origin, direction, distance)

	scan_completed.emit(distances)
	return distances


func _update_ray_visual(index: int, origin: Vector3, direction: Vector3, distance: float) -> void:
	if not _line_multimesh or index >= _line_multimesh.instance_count:
		return

	var transform = Transform3D()
	transform.origin = origin + direction * (distance / 2.0)
	transform.basis = Basis.looking_at(direction, Vector3.UP)
	transform.basis = transform.basis.rotated(Vector3.UP, PI / 2.0)

	var scale = Vector3(1, 1, distance)
	transform = transform.scaled(scale)

	_line_multimesh.set_instance_transform(index, transform)

	# Color based on distance
	var color = Color(0.0, 1.0, 0.0) if distance < _max_range * 0.3 else \
		Color(1.0, 1.0, 0.0) if distance < _max_range * 0.7 else \
		Color(1.0, 0.0, 0.0)
	_line_multimesh.set_instance_color(index, color)


func set_debug_visible(visible: bool) -> void:
	_debug_lines = visible
	if _multimesh_instance:
		_multimesh_instance.visible = visible
