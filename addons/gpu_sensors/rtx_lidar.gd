# rtx_lidar.gd
# GPU ray tracing LIDAR sensor using PyTorch CUDA
# Hardware-accelerated ray casting for realistic LIDAR simulation

class_name RTXLidar
extends Node3D


## ===== LIDAR Configuration =====

var _model: String = "Velodyne VLP-16"
var _num_rays: int = 16
var _max_range: float = 100.0
var _min_range: float = 0.5
var _horizontal_fov: float = 360.0
var _vertical_fov: float = 30.0
var _rotation_rate: float = 10.0  # Hz
var _noise_model: String = "gaussian"


## ===== Noise Parameters =====

var _noise_scale: float = 0.02
var _noise_mean: float = 0.0
var _noise_stddev: float = 0.02


## ===== Point Cloud =====

var _points: Array = []
var _point_cloud: Array = []  # XYZ + intensity
var _last_scan_time: float = 0.0


## ===== Laser Configuration =====

var _laser_angles: Array = []  # Vertical angles per ring
var _laser_intensities: Array = []


## ===== Signals =====

signal scan_complete(point_cloud: Array)
signal error(message: String)


## ===== Model Specs =====

const VLP_16_SPECS = {
	"num_rays": 16,
	"vertical_fov": 30.0,
	"vertical_angles": [-15.0, -13.0, -11.0, -9.0, -7.0, -5.0, -3.0, -1.0, 1.0, 3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0],
	"horizontal_fov": 360.0,
	"rotation_rate": 10.0,
	"max_range": 100.0,
	"range_resolution": 0.002
}

const HDL_32E_SPECS = {
	"num_rays": 32,
	"vertical_fov": 41.33,
	"vertical_angles": [-30.67, -29.33, -28.0, -26.67, -25.33, -24.0, -22.67, -21.33, -20.0, -18.67, -17.33, -16.0, -14.67, -13.33, -12.0, -10.67, -9.33, -8.0, -6.67, -5.33, -4.0, -2.67, -1.33, 0.0, 1.33, 2.67, 4.0, 5.33, 6.67, 8.0, 9.33, 10.67],
	"horizontal_fov": 360.0,
	"rotation_rate": 10.0,
	"max_range": 70.0,
	"range_resolution": 0.002
}

const HDL_64E_SPECS = {
	"num_rays": 64,
	"vertical_fov": 26.8,
	"vertical_angles": [-24.0, -22.67, -21.33, -20.0, -18.67, -17.33, -16.0, -14.67, -13.33, -12.0, -10.67, -9.33, -8.0, -6.67, -5.33, -4.0, -2.67, -1.33, 0.0, 1.33, 2.67, 4.0, 5.33, 6.67, 8.0, 9.33, 10.67, 12.0, 13.33, 14.67, 16.0, 17.33, 18.67, 20.0, 21.33, 22.67, 24.0],
	"horizontal_fov": 360.0,
	"rotation_rate": 10.0,
	"max_range": 120.0,
	"range_resolution": 0.002
}


## ===== Initialization =====

func _ready() -> void:
	_setup_laser_angles()


func initialize(config: Dictionary) -> bool:
	_model = config.get("model", _model)
	_num_rays = config.get("num_rays", _num_rays)
	_max_range = config.get("max_range", _max_range)
	_min_range = config.get("min_range", _min_range)
	_horizontal_fov = config.get("horizontal_fov", _horizontal_fov)
	_vertical_fov = config.get("vertical_fov", _vertical_fov)
	_noise_model = config.get("noise_model", _noise_model)
	_noise_scale = config.get("noise_scale", _noise_scale)

	# Apply model-specific defaults
	_apply_model_specs()
	_setup_laser_angles()

	return true


## ===== Scanning =====

func scan() -> Array:
	# Perform a full 360° scan
	_points.clear()

	var start_angle = 0.0
	var end_angle = _horizontal_fov
	var angle_increment = _horizontal_fov / 360.0

	for angle in range(360):
		var rays = _cast_rays_at_angle(float(angle))
		_points.append_array(rays)

	_last_scan_time = Time.get_unix_time_from_system()
	scan_complete.emit(_points)
	return _points


func scan_continuous(delta: float) -> Array:
	# Continuous scanning at rotation_rate
	var angle_increment = _rotation_rate * delta
	var current_angle = fposmod(_last_scan_time * _rotation_rate, 360.0)

	_points.clear()

	# Cast rays for current angle
	var rays = _cast_rays_at_angle(current_angle)
	_points.append_array(rays)

	scan_complete.emit(_points)
	return _points


## ===== Ray Casting =====

func _cast_rays_at_angle(angle_degrees: float) -> Array:
	var rays = []

	for i in range(_num_rays):
		var vertical_angle = _laser_angles[i] if i < _laser_angles.size() else 0.0
		var direction = _compute_ray_direction(angle_degrees, vertical_angle)

		# GPU raycast via Python subprocess
		var hit = _gpu_raycast(global_position, direction)

		if hit.size() > 0:
			var range = hit[0]
			if range >= _min_range and range <= _max_range:
				# Add noise
				var noisy_range = _add_noise(range)
				var point = _range_to_point(angle_degrees, vertical_angle, noisy_range)
				point.append(_laser_intensities[i] if i < _laser_intensities.size() else 1.0)
				rays.append(point)

	return rays


func _gpu_raycast(origin: Vector3, direction: Vector3) -> Array:
	# GPU-accelerated raycast via PyTorch CUDA
	var temp_dir = "/tmp/copernicus_lidar_%d" % OS.get_process_id()
	var cmd_file = temp_dir + "/cmd.json"
	var resp_file = temp_dir + "/resp.json"

	OS.execute("mkdir", ["-p", temp_dir], [], true)

	var cmd = {
		"cmd": "raycast",
		"origin": [origin.x, origin.y, origin.z],
		"direction": [direction.x, direction.y, direction.z],
		"max_distance": _max_range
	}

	var f = FileAccess.open(cmd_file, FileAccess.WRITE)
	if f == null:
		return []
	f.store_string(JSON.stringify(cmd))
	f.close()

	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/backends/compute_raycast.py")
	if not FileAccess.file_exists(script_path):
		# Fallback to CPU raycast
		return _cpu_raycast_fallback(origin, direction)

	var escaped_script = script_path.replace("\\", "\\\\").replace("'", "\\'")

	var output = []
	OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('compute_raycast', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with open('%s', 'r') as f:
    cmd = json.load(f)

raycaster = module.ComputeRaycast()
result = raycaster.raycast(cmd['origin'], cmd['direction'], cmd['max_distance'])

with open('%s', 'w') as f:
    json.dump({'ranges': result}, f)
""" % (escaped_script, escaped_script, cmd_file.replace("\\", "\\\\").replace("'", "\\'"), resp_file.replace("\\", "\\\\").replace("'", "\\'"))], output, true)

	f = FileAccess.open(resp_file, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		OS.execute("rm", ["-rf", temp_dir], [], true)
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			return parsed.get("ranges", [])

	return []


func _cpu_raycast_fallback(origin: Vector3, direction: Vector3) -> Array:
	# CPU fallback using Godot raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * _max_range)

	var result = space_state.intersect_ray(query)
	if result:
		return [origin.distance_to(result.position)]
	return [_max_range]


func _compute_ray_direction(horizontal_angle: float, vertical_angle: float) -> Vector3:
	var h_rad = deg_to_rad(horizontal_angle)
	var v_rad = deg_to_rad(vertical_angle)

	var direction = Vector3.ZERO
	direction.x = sin(h_rad) * cos(v_rad)
	direction.y = -sin(v_rad)
	direction.z = cos(h_rad) * cos(v_rad)

	return direction.normalized()


func _range_to_point(horizontal_angle: float, vertical_angle: float, range: float) -> Array:
	# Convert spherical to Cartesian
	var h_rad = deg_to_rad(horizontal_angle)
	var v_rad = deg_to_rad(vertical_angle)

	var x = range * sin(h_rad) * cos(v_rad)
	var y = range * -sin(v_rad)
	var z = range * cos(h_rad) * cos(v_rad)

	return [x, y, z]


## ===== Noise Models =====

func _add_noise(range: float) -> float:
	match _noise_model:
		"gaussian":
			return range + randfn(_noise_mean, _noise_stddev)
		"uniform":
			return range + randf_range(-_noise_scale, _noise_scale)
		"none":
			return range
		_:
			return range


## ===== Configuration =====

func _apply_model_specs() -> void:
	match _model:
		"Velodyne VLP-16":
			var specs = VLP_16_SPECS
			_num_rays = specs["num_rays"]
			_vertical_fov = specs["vertical_fov"]
			_max_range = specs["max_range"]
		"Velodyne HDL-32E":
			var specs = HDL_32E_SPECS
			_num_rays = specs["num_rays"]
			_vertical_fov = specs["vertical_fov"]
			_max_range = specs["max_range"]
		"Velodyne HDL-64E":
			var specs = HDL_64E_SPECS
			_num_rays = specs["num_rays"]
			_vertical_fov = specs["vertical_fov"]
			_max_range = specs["max_range"]


func _setup_laser_angles() -> void:
	# Default uniform distribution
	_laser_angles.clear()
	var angle_step = _vertical_fov / float(_num_rays - 1)
	var start_angle = -_vertical_fov / 2.0

	for i in range(_num_rays):
		_laser_angles.append(start_angle + i * angle_step)

	# Default intensities
	_laser_intensities.clear()
	for i in range(_num_rays):
		_laser_intensities.append(1.0)


func set_rotation_rate(hz: float) -> void:
	_rotation_rate = hz


func set_noise_parameters(scale: float, mean: float, stddev: float) -> void:
	_noise_scale = scale
	_noise_mean = mean
	_noise_stddev = stddev


func set_noise_model(model: String) -> void:
	_noise_model = model


## ===== Point Cloud Access =====

func get_point_cloud() -> Array:
	return _point_cloud.duplicate()


func get_points_as_vertices() -> Array:
	# Convert to PackedVector3Array for visualization
	var vertices = PackedVector3Array()
	for point in _points:
		if point.size() >= 3:
			vertices.append(Vector3(point[0], point[1], point[2]))
	return vertices


func get_range_image() -> Array:
	# Create range image as 2D array
	var image_width = 360
	var image_height = _num_rays
	var range_image = []

	for row in range(image_height):
		range_image.append([])

	# Map points to image coordinates
	for point in _points:
		if point.size() >= 4:
			var x = point[0]
			var z = point[2]
			var angle = rad_to_deg(atan2(x, z))
			if angle < 0:
				angle += 360.0

			var col = int(angle) % image_width
			var row = int((point[1] + _vertical_fov / 2.0) / _vertical_fov * image_height)
			row = clamp(row, 0, image_height - 1)

			range_image[row].append(point[3])  # range or intensity

	return range_image


## ===== Model Configuration =====

func configure_laser(model: String) -> void:
	_model = model
	_apply_model_specs()
	_setup_laser_angles()


func get_model_specs() -> Dictionary:
	return {
		"model": _model,
		"num_rays": _num_rays,
		"max_range": _max_range,
		"horizontal_fov": _horizontal_fov,
		"vertical_fov": _vertical_fov,
		"rotation_rate": _rotation_rate
	}
