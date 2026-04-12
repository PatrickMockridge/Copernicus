# path_visualizer.gd
# 3D visualization for navigation paths
# Renders paths as Line3D or ImmediateMesh with waypoint spheres

class_name PathVisualizer
extends Node3D

## Path line mesh
var _path_mesh: MeshInstance3D
var _path_immediate: ImmediateMesh

## Waypoint spheres
var _waypoint_mesh: MultiMeshInstance3D
var _waypoint_multimesh: MultiMesh

## Current path
var _current_path: Array = []

## Path settings
var _path_color: Color = Color(0.2, 0.8, 1.0, 0.8)
var _waypoint_color: Color = Color(1.0, 0.5, 0.2, 1.0)
var _path_width: float = 0.02
var _waypoint_radius: float = 0.05

## Animation
var _is_animating: bool = false
var _animation_speed: float = 1.0  # meters per second
var _animation_offset: float = 0.0


func _ready() -> void:
	_setup_path_mesh()
	_setup_waypoint_mesh()


func _setup_path_mesh() -> void:
	_path_immediate = ImmediateMesh.new()
	_path_mesh = MeshInstance3D.new()
	_path_mesh.mesh = _path_immediate
	_path_mesh.name = "PathLine"

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _path_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mesh.material_override = mat

	add_child(_path_mesh)


func _setup_waypoint_mesh() -> void:
	_waypoint_multimesh = MultiMesh.new()
	_waypoint_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_waypoint_multimesh.use_colors = true

	var sphere = SphereMesh.new()
	sphere.radius = _waypoint_radius
	sphere.height = _waypoint_radius * 2
	_waypoint_multimesh.mesh = sphere
	_waypoint_multimesh.instance_count = 0

	_waypoint_mesh = MultiMeshInstance3D.new()
	_waypoint_mesh.multimesh = _waypoint_multimesh
	_waypoint_mesh.name = "Waypoints"

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _waypoint_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_waypoint_mesh.material_override = mat

	add_child(_waypoint_mesh)


## ===== Path Visualization =====

func visualize_path(path: Array) -> void:
	_current_path = path

	if path.is_empty():
		clear_path()
		return

	_draw_path_line(path)
	_draw_waypoints(path)


func _draw_path_line(path: Array) -> void:
	_path_immediate.clear()

	if path.size() < 2:
		return

	_path_immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for pos in path:
		var world_pos = _to_world_pos(pos)
		_path_immediate.surface_add_vertex(world_pos)

	_path_immediate.surface_end()


func _draw_waypoints(path: Array) -> void:
	_waypoint_multimesh.instance_count = path.size()

	for i in range(path.size()):
		var world_pos = _to_world_pos(path[i])
		var transform = Transform3D()
		transform.origin = world_pos
		_waypoint_multimesh.set_instance_transform(i, transform)

		# Color based on position in path (gradient)
		var t = float(i) / float(max(1, path.size() - 1))
		var color = Color(
			lerp(_waypoint_color.r, 1.0, t * 0.5),
			lerp(_waypoint_color.g, 1.0, t * 0.5),
			lerp(_waypoint_color.b, 0.5, t * 0.5),
			1.0
		)
		_waypoint_multimesh.set_instance_color(i, color)


func _to_world_pos(pos) -> Vector3:
	if pos is Vector3:
		return Vector3(pos.x, 0.1, pos.z)
	elif pos is Vector2:
		return Vector3(pos.x, 0.1, pos.y)
	return Vector3(pos.x, 0.1, pos.z)


func clear_path() -> void:
	_current_path.clear()
	_path_immediate.clear()
	_waypoint_multimesh.instance_count = 0


## ===== Path Animation =====

func animate_along_path(path: Array, robot: Node3D, speed: float = 1.0) -> void:
	if path.is_empty():
		return

	_current_path = path
	_animation_speed = speed
	_is_animating = true

	_animation_offset = 0.0


func _process(delta: float) -> void:
	if not _is_animating or _current_path.is_empty():
		return

	_animation_offset += _animation_speed * delta

	# Find current segment
	var total_length = _calculate_path_length(_current_path)

	if _animation_offset >= total_length:
		_animation_offset = 0.0  # Loop

	# Find position along path
	var pos = _get_position_at_distance(_current_path, _animation_offset)

	# Update something (could be a marker, robot would need external control)
	pass


func _calculate_path_length(path: Array) -> float:
	if path.size() < 2:
		return 0.0

	var length = 0.0
	for i in range(1, path.size()):
		var p1 = _to_world_pos(path[i - 1])
		var p2 = _to_world_pos(path[i])
		length += p1.distance_to(p2)

	return length


func _get_position_at_distance(path: Array, distance: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO

	if path.size() == 1:
		return _to_world_pos(path[0])

	var accumulated = 0.0

	for i in range(1, path.size()):
		var p1 = _to_world_pos(path[i - 1])
		var p2 = _to_world_pos(path[i])
		var segment_length = p1.distance_to(p2)

		if accumulated + segment_length >= distance:
			# Interpolate within this segment
			var t = (distance - accumulated) / segment_length
			return p1.lerp(p2, t)

		accumulated += segment_length

	return _to_world_pos(path[path.size() - 1])


func stop_animation() -> void:
	_is_animating = false


func is_animating() -> bool:
	return _is_animating


## ===== Configuration =====

func set_path_color(color: Color) -> void:
	_path_color = color
	if _path_mesh and _path_mesh.material_override:
		(_path_mesh.material_override as StandardMaterial3D).albedo_color = color


func set_waypoint_color(color: Color) -> void:
	_waypoint_color = color
	if _waypoint_mesh and _waypoint_mesh.material_override:
		(_waypoint_mesh.material_override as StandardMaterial3D).albedo_color = color


func set_path_width(width: float) -> void:
	_path_width = width


func set_waypoint_radius(radius: float) -> void:
	_waypoint_radius = radius
	if _waypoint_multimesh and _waypoint_multimesh.mesh:
		var sphere = _waypoint_multimesh.mesh as SphereMesh
		if sphere:
			sphere.radius = radius
			sphere.height = radius * 2


## ===== Visualization Modes =====

func show_path_only() -> void:
	_path_mesh.visible = true
	_waypoint_mesh.visible = false


func show_waypoints_only() -> void:
	_path_mesh.visible = false
	_waypoint_mesh.visible = true


func show_all() -> void:
	_path_mesh.visible = true
	_waypoint_mesh.visible = true


func hide_all() -> void:
	_path_mesh.visible = false
	_waypoint_mesh.visible = false


## ===== Static Helpers =====

static func visualize_path_on_node(parent: Node3D, path: Array) -> PathVisualizer:
	var viz = PathVisualizer.new()
	parent.add_child(viz)
	viz.visualize_path(path)
	return viz
