# domain_randomizer.gd
# Scene domain randomization for synthetic data generation.
# Randomizes lighting, camera pose, background distractors, and material colors.
# Works with any Godot scene — opt-in and scene-agnostic.

class_name DomainRandomizer
extends RefCounted


## ===== References =====

var _scene_root: Node3D = null
var _camera: Camera3D = null
var _lights: Array = []
var _material_targets: Array = []
var _base_camera_transform: Transform3D = Transform3D.IDENTITY
var _base_camera_fov: float = 75.0


## ===== Background Distractors =====

var _distractor_pool: Array = []
var _distractor_count: int = 5
var _distractor_min_dist: float = 2.0
var _distractor_max_dist: float = 10.0
var _distractor_parent: Node3D = null

## ===== Ranges =====

var _lighting_hue_shift: float = 15.0
var _lighting_energy_range: float = 0.3
var _lighting_angle_jitter: float = 10.0

var _camera_pos_jitter: float = 0.05
var _camera_fov_jitter: float = 2.0
var _camera_roll_jitter: float = 3.0

var _material_hue_shift: float = 10.0
var _material_lightness_range: float = 0.15


## ===== Setup =====

func setup(scene_root: Node3D, camera: Camera3D, lights: Array = []) -> void:
	_scene_root = scene_root
	_camera = camera
	_lights = lights
	if _camera:
		_base_camera_transform = _camera.transform
		_base_camera_fov = _camera.fov
	_auto_discover_lights()
	_auto_discover_materials()


func _auto_discover_lights() -> void:
	if not _lights.is_empty():
		return
	if not _scene_root:
		return
	_find_lights_recursive(_scene_root)


func _find_lights_recursive(node: Node) -> void:
	if node is DirectionalLight3D or node is OmniLight3D or node is SpotLight3D:
		_lights.append(node)
	for child in node.get_children():
		_find_lights_recursive(child)


func _auto_discover_materials() -> void:
	if not _scene_root:
		return
	_find_meshes_recursive(_scene_root)


func _find_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_material_targets.append(node)
	for child in node.get_children():
		_find_meshes_recursive(child)


func set_material_targets(targets: Array) -> void:
	_material_targets = targets


func set_background_density(count: int) -> void:
	_distractor_count = count


## ===== Full Randomization =====

func randomize_all() -> void:
	randomize_lighting()
	randomize_camera()
	randomize_background()
	randomize_materials()


## ===== Lighting =====

func randomize_lighting() -> void:
	for light in _lights:
		if light is DirectionalLight3D:
			var dir_light = light as DirectionalLight3D
			dir_light.light_energy = _jitter_float(dir_light.light_energy, _lighting_energy_range)
			dir_light.rotation_degrees.x += randf_range(-_lighting_angle_jitter, _lighting_angle_jitter)
			dir_light.rotation_degrees.y += randf_range(-_lighting_angle_jitter, _lighting_angle_jitter)
			dir_light.light_color = _shift_hue(dir_light.light_color, _lighting_hue_shift)
		elif light is OmniLight3D:
			var omni = light as OmniLight3D
			omni.light_energy = _jitter_float(omni.light_energy, _lighting_energy_range)
			omni.light_color = _shift_hue(omni.light_color, _lighting_hue_shift)
		elif light is SpotLight3D:
			var spot = light as SpotLight3D
			spot.light_energy = _jitter_float(spot.light_energy, _lighting_energy_range)
			spot.light_color = _shift_hue(spot.light_color, _lighting_hue_shift)


## ===== Camera =====

func randomize_camera() -> void:
	if not _camera:
		return

	# Reset to the base pose/FOV so repeated calls don't drift unboundedly.
	_camera.transform = _base_camera_transform
	_camera.fov = _base_camera_fov

	# Position jitter in camera-local space
	var right = _camera.global_transform.basis.x
	var up = _camera.global_transform.basis.y
	var forward = -_camera.global_transform.basis.z

	_camera.position += right * randfn(0.0, _camera_pos_jitter)
	_camera.position += up * randfn(0.0, _camera_pos_jitter)
	_camera.position += forward * randfn(0.0, _camera_pos_jitter * 0.5)

	# FOV jitter (clamped to a valid range)
	_camera.fov = clampf(_camera.fov + randf_range(-_camera_fov_jitter, _camera_fov_jitter), 10.0, 120.0)

	# Roll jitter (rotate around forward axis)
	var roll = randfn(0.0, _camera_roll_jitter)
	_camera.rotate_object_local(Vector3(0, 0, -1), deg_to_rad(roll))


## ===== Background Distractors =====

func randomize_background() -> void:
	_ensure_distractor_parent()
	_ensure_distractor_pool()

	var camera_pos = _camera.global_position if _camera else Vector3.ZERO
	var camera_forward = -_camera.global_transform.basis.z if _camera else Vector3(0, 0, -1)

	for i in range(_distractor_pool.size()):
		var distractor: MeshInstance3D = _distractor_pool[i]
		var angle = randf() * TAU
		var dist = randf_range(_distractor_min_dist, _distractor_max_dist)
		var height = randf_range(-1.5, 1.5)

		# Place in a ring around the camera, in the general forward direction
		var offset = camera_forward.rotated(Vector3.UP, angle) * dist
		offset.y = height
		distractor.position = camera_pos + offset

		# Random scale
		var s = randf_range(0.3, 1.5)
		distractor.scale = Vector3(s, s, s)

		# Random color
		if distractor.material_override is StandardMaterial3D:
			var mat = distractor.material_override as StandardMaterial3D
			mat.albedo_color = Color.from_hsv(randf(), randf_range(0.3, 0.8), randf_range(0.3, 0.9))


func _ensure_distractor_parent() -> void:
	if _distractor_parent and is_instance_valid(_distractor_parent):
		return
	_distractor_parent = Node3D.new()
	_distractor_parent.set_name("Distractors")
	if _scene_root:
		_scene_root.add_child(_distractor_parent)


func _ensure_distractor_pool() -> void:
	if _distractor_pool.size() >= _distractor_count:
		return

	var shapes = [
		BoxMesh.new(),
		SphereMesh.new(),
		CylinderMesh.new()
	]
	for shape in shapes:
		if shape is CylinderMesh:
			shape.top_radius = 0.15
			shape.bottom_radius = 0.15
			shape.height = 0.4

	while _distractor_pool.size() < _distractor_count:
		var mesh_instance = MeshInstance3D.new()
		var idx = _distractor_pool.size() % shapes.size()
		mesh_instance.mesh = shapes[idx]

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.from_hsv(randf(), 0.5, 0.7)
		mesh_instance.material_override = mat

		_distractor_parent.add_child(mesh_instance)
		_distractor_pool.append(mesh_instance)


## ===== Materials =====

func randomize_materials() -> void:
	var targets = _material_targets if _material_targets.size() > 0 else []
	if targets.is_empty() and _scene_root:
		_find_meshes_recursive(_scene_root)
		targets = _material_targets

	for mesh_instance in _material_targets:
		if not mesh_instance is MeshInstance3D:
			continue
		var mi = mesh_instance as MeshInstance3D
		var mat: Material = mi.material_override
		var from_surface := false
		if mat == null and mi.mesh != null:
			mat = mi.mesh.surface_get_material(0)
			from_surface = true
		if mat is StandardMaterial3D:
			var dup = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.albedo_color = _shift_hue_lightness(dup.albedo_color, _material_hue_shift, _material_lightness_range)
			if from_surface:
				var mesh_dup = mi.mesh.duplicate() as Mesh
				mi.mesh = mesh_dup
				mesh_dup.surface_set_material(0, dup)
			else:
				mi.material_override = dup


## ===== Color Helpers =====

func _shift_hue(color: Color, hue_range: float) -> Color:
	var h = color.h + randf_range(-hue_range / 360.0, hue_range / 360.0)
	h = fposmod(h, 1.0)
	return Color.from_hsv(h, color.s, color.v, color.a)


func _shift_hue_lightness(color: Color, hue_range: float, lightness_range: float) -> Color:
	var h = color.h + randf_range(-hue_range / 360.0, hue_range / 360.0)
	h = fposmod(h, 1.0)
	var v = clamp(color.v + randf_range(-lightness_range, lightness_range), 0.0, 1.0)
	return Color.from_hsv(h, color.s, v, color.a)


func _jitter_float(value: float, frac: float) -> float:
	return max(value * (1.0 + randf_range(-frac, frac)), 0.0)
