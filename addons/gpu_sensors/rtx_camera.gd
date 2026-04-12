# rtx_camera.gd
# GPU path tracing camera sensor
# Path tracing for camera with global illumination and realistic noise

class_name RTXCamera
extends Camera3D


## ===== Camera Configuration =====

var _model: String = "Intel RealSense D455"
var _width: int = 640
var _height: int = 480
var _fov: float = 60.0
var _depth_enabled: bool = true
var _color_enabled: bool = true


## ===== Camera Intrinsics =====

var _fx: float = 554.0  # Focal length x
var _fy: float = 554.0  # Focal length y
var _cx: float = 320.0  # Principal point x
var _cy: float = 240.0  # Principal point y
var _k1: float = 0.0   # Radial distortion k1
var _k2: float = 0.0   # Radial distortion k2
var _p1: float = 0.0   # Tangential distortion p1
var _p2: float = 0.0   # Tangential distortion p2


## ===== Capture State =====

var _last_color_image: Array = []
var _last_depth_image: Array = []
var _last_ir_image: Array = []
var _last_timestamp: float = 0.0


## ===== Noise Models =====

var _color_noise_stddev: float = 10.0
var _depth_noise_model: String = "spatial"
var _depth_noise_stddev: float = 0.02


## ===== Signals =====

signal frame_captured(color: Array, depth: Array)
signal error(message: String)


## ===== Model Specs =====

const REALSENSE_D455_SPECS = {
	"model": "Intel RealSense D455",
	"width": 640,
	"height": 480,
	"fov": 87.0,
	"fx": 554.0,
	"fy": 554.0,
	"cx": 320.0,
	"cy": 240.0
}

const KINECT_AZURE_SPECS = {
	"model": "Azure Kinect DK",
	"width": 640,
	"height": 576,
	"fov": 120.0,
	"fx": 554.0,
	"fy": 554.0,
	"cx": 320.0,
	"cy": 288.0
}

const ZED_2I_SPECS = {
	"model": "ZED 2i",
	"width": 1280,
	"height": 720,
	"fov": 110.0,
	"fx": 554.0,
	"fy": 554.0,
	"cx": 640.0,
	"cy": 360.0
}


## ===== Initialization =====

func _ready() -> void:
	_apply_model_specs()


func initialize(config: Dictionary) -> bool:
	_model = config.get("model", _model)
	_width = config.get("width", _width)
	_height = config.get("height", _height)
	_fov = config.get("fov", _fov)
	_color_enabled = config.get("color_enabled", _color_enabled)
	_depth_enabled = config.get("depth_enabled", _depth_enabled)

	_apply_model_specs()
	_setup_projection()

	return true


## ===== Capture =====

func capture() -> Dictionary:
	# Capture RGB and depth image
	var result = {
		"timestamp": Time.get_unix_time_from_system(),
		"color": _capture_color(),
		"depth": _capture_depth() if _depth_enabled else [],
		"ir": _capture_ir() if _depth_enabled else []
	}

	_last_timestamp = result["timestamp"]
	_last_color_image = result["color"]
	_last_depth_image = result["depth"]
	_last_ir_image = result["ir"]

	frame_captured.emit(result["color"], result["depth"])
	return result


func capture_color() -> Array:
	return _capture_color()


func capture_depth() -> Array:
	return _capture_depth()


## ===== GPU Capture =====

func _capture_color() -> Array:
	# GPU path-traced color capture
	var temp_dir = "/tmp/copernicus_camera_%d" % OS.get_process_id()
	var cmd_file = temp_dir + "/cmd.json"
	var resp_file = temp_dir + "/resp.json"

	OS.execute("mkdir", ["-p", temp_dir], [], true)

	var cmd = {
		"cmd": "capture_color",
		"camera_pose": [global_position.x, global_position.y, global_position.z],
		"camera_forward": [global_transform.basis.z.x, global_transform.basis.z.y, global_transform.basis.z.z],
		"width": _width,
		"height": _height,
		"fov": _fov,
		"noise_stddev": _color_noise_stddev
	}

	var f = FileAccess.open(cmd_file, FileAccess.WRITE)
	if f == null:
		return []
	f.store_string(JSON.stringify(cmd))
	f.close()

	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/backends/rtx_camera.py")
	if not FileAccess.file_exists(script_path):
		return _capture_color_fallback()

	var escaped_script = script_path.replace("\\", "\\\\").replace("'", "\\'")

	var output = []
	OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('rtx_camera', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with open('%s', 'r') as f:
    cmd = json.load(f)

camera = module.RTXCameraSimulator()
result = camera.capture(cmd)

with open('%s', 'w') as f:
    json.dump(result, f)
""" % (escaped_script, escaped_script, cmd_file.replace("\\", "\\\\").replace("'", "\\'"), resp_file.replace("\\", "\\\\").replace("'", "\\'"))], output, true)

	f = FileAccess.open(resp_file, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		OS.execute("rm", ["-rf", temp_dir], [], true)
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			return parsed.get("color", [])

	return []


func _capture_depth() -> Array:
	# GPU depth capture
	var temp_dir = "/tmp/copernicus_depth_%d" % OS.get_process_id()
	var cmd_file = temp_dir + "/cmd.json"
	var resp_file = temp_dir + "/resp.json"

	OS.execute("mkdir", ["-p", temp_dir], [], true)

	var cmd = {
		"cmd": "capture_depth",
		"camera_pose": [global_position.x, global_position.y, global_position.z],
		"camera_forward": [global_transform.basis.z.x, global_transform.basis.z.y, global_transform.basis.z.z],
		"width": _width,
		"height": _height,
		"fov": _fov,
		"noise_model": _depth_noise_model,
		"noise_stddev": _depth_noise_stddev
	}

	var f = FileAccess.open(cmd_file, FileAccess.WRITE)
	if f == null:
		return []
	f.store_string(JSON.stringify(cmd))
	f.close()

	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/backends/rtx_camera.py")
	if not FileAccess.file_exists(script_path):
		return _capture_depth_fallback()

	var escaped_script = script_path.replace("\\", "\\\\").replace("'", "\\'")

	var output = []
	OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('rtx_camera', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with open('%s', 'r') as f:
    cmd = json.load(f)

camera = module.RTXCameraSimulator()
result = camera.capture_depth(cmd)

with open('%s', 'w') as f:
    json.dump(result, f)
""" % (escaped_script, escaped_script, cmd_file.replace("\\", "\\\\").replace("'", "\\'"), resp_file.replace("\\", "\\\\").replace("'", "\\'"))], output, true)

	f = FileAccess.open(resp_file, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		OS.execute("rm", ["-rf", temp_dir], [], true)
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			return parsed.get("depth", [])

	return []


func _capture_ir() -> Array:
	# Simulated IR image (depth cameras often have IR)
	var ir_image = []
	for y in range(_height):
		var row = []
		for x in range(_width):
			row.append(randf() * 100)  # Random IR values
		ir_image.append(row)
	return ir_image


## ===== CPU Fallback =====

func _capture_color_fallback() -> Array:
	# CPU fallback using Godot's renderer
	var image = Image.create(_width, _height, false, Image.FORMAT_RGB8)
	image.fill(Color(0.5, 0.5, 0.5))  # Gray fallback

	var color_data = []
	for y in range(_height):
		var row = []
		for x in range(_width):
			var pixel = image.get_pixel(x, y)
			row.append([pixel.r * 255, pixel.g * 255, pixel.b * 255])
		color_data.append(row)

	return color_data


func _capture_depth_fallback() -> Array:
	# CPU depth fallback using raycast
	var space_state = get_world_3d().direct_space_state
	var depth_image = []

	var fov_rad = deg_to_rad(_fov)
	var aspect_ratio = float(_width) / float(_height)

	var ray_directions = []
	for y in range(_height):
		var row = []
		for x in range(_width):
			var u = (x / float(_width)) * 2.0 - 1.0
			var v = (y / float(_height)) * 2.0 - 1.0
			var u_scaled = u * tan(fov_rad / 2.0) * aspect_ratio
			var v_scaled = v * tan(fov_rad / 2.0)

			var ray_dir = Vector3(u_scaled, -v_scaled, -1.0).normalized()
			ray_dir = global_transform.basis * ray_dir

			var query = PhysicsRayQueryParameters3D.create(global_position, global_position + ray_dir * 10.0)
			var result = space_state.intersect_ray(query)

			if result:
				row.append(global_position.distance_to(result.position))
			else:
				row.append(0.0)
		depth_image.append(row)

	return depth_image


## ===== Configuration =====

func _apply_model_specs() -> void:
	match _model:
		"Intel RealSense D455":
			var specs = REALSENSE_D455_SPECS
			_width = specs["width"]
			_height = specs["height"]
			_fov = specs["fov"]
			_fx = specs["fx"]
			_fy = specs["fy"]
			_cx = specs["cx"]
			_cy = specs["cy"]
		"Azure Kinect DK":
			var specs = KINECT_AZURE_SPECS
			_width = specs["width"]
			_height = specs["height"]
			_fov = specs["fov"]
			_fx = specs["fx"]
			_fy = specs["fy"]
			_cx = specs["cx"]
			_cy = specs["cy"]
		"ZED 2i":
			var specs = ZED_2I_SPECS
			_width = specs["width"]
			_height = specs["height"]
			_fov = specs["fov"]
			_fx = specs["fx"]
			_fy = specs["fy"]
			_cx = specs["cx"]
			_cy = specs["cy"]


func _setup_projection() -> void:
	# Set camera projection
	var fov_rad = deg_to_rad(_fov)
	var aspect = float(_width) / float(_height)
	projection = PROJECTION_PERSPECTIVE
	fov_scale = fov_rad
	aspect_ratio = aspect


## ===== Intrinsics =====

func get_intrinsics() -> Dictionary:
	return {
		"fx": _fx,
		"fy": _fy,
		"cx": _cx,
		"cy": _cy,
		"k1": _k1,
		"k2": _k2,
		"p1": _p1,
		"p2": _p2,
		"width": _width,
		"height": _height
	}


func set_intrinsics(fx: float, fy: float, cx: float, cy: float) -> void:
	_fx = fx
	_fy = fy
	_cx = cx
	_cy = cy


func set_distortion(k1: float, k2: float, p1: float, p2: float) -> void:
	_k1 = k1
	_k2 = k2
	_p1 = p1
	_p2 = p2


## ===== Noise =====

func set_color_noise(stddev: float) -> void:
	_color_noise_stddev = stddev


func set_depth_noise(model: String, stddev: float) -> void:
	_depth_noise_model = model
	_depth_noise_stddev = stddev


## ===== Last Frame Access =====

func get_last_color() -> Array:
	return _last_color_image.duplicate()


func get_last_depth() -> Array:
	return _last_depth_image.duplicate()


func get_last_timestamp() -> float:
	return _last_timestamp


## ===== Model Configuration =====

func configure_camera(model: String) -> void:
	_model = model
	_apply_model_specs()
	_setup_projection()


func get_model_specs() -> Dictionary:
	return {
		"model": _model,
		"width": _width,
		"height": _height,
		"fov": _fov,
		"color_enabled": _color_enabled,
		"depth_enabled": _depth_enabled
	}
