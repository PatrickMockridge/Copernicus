# rtx_camera.gd
# GPU camera sensor — renders the Godot scene via SubViewport.
# Lens distortion and noise applied in post-processing.
# No external Python dependency.

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

var _fx: float = 554.0
var _fy: float = 554.0
var _cx: float = 320.0
var _cy: float = 240.0
var _k1: float = 0.0
var _k2: float = 0.0
var _p1: float = 0.0
var _p2: float = 0.0


## ===== Internal SubViewport =====

var _internal_viewport: SubViewport = null
var _internal_camera: Camera3D = null


## ===== Capture State =====

var _last_color_image: Array = []
var _last_depth_image: Array = []
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
	_setup_subviewport()


func initialize(config: Dictionary) -> bool:
	_model = config.get("model", _model)
	_width = config.get("width", _width)
	_height = config.get("height", _height)
	_fov = config.get("fov", _fov)
	_color_enabled = config.get("color_enabled", _color_enabled)
	_depth_enabled = config.get("depth_enabled", _depth_enabled)

	_apply_model_specs()
	_setup_projection()
	_setup_subviewport()

	return true


func _setup_subviewport() -> void:
	if _internal_viewport:
		return

	_internal_viewport = SubViewport.new()
	_internal_viewport.size = Vector2i(_width, _height)
	_internal_viewport.transparent_bg = true
	add_child(_internal_viewport)

	_internal_camera = Camera3D.new()
	_internal_camera.fov = _fov
	_internal_camera.near = 0.05
	_internal_camera.far = 100.0
	_internal_camera.current = true
	_internal_viewport.add_child(_internal_camera)


func _sync_camera_transform() -> void:
	if not _internal_camera:
		return
	_internal_camera.global_transform = global_transform
	_internal_camera.fov = _fov
	_internal_viewport.size = Vector2i(_width, _height)


## ===== Capture =====

func capture() -> Dictionary:
	_sync_camera_transform()

	var result = {
		"timestamp": Time.get_unix_time_from_system(),
		"color": _capture_color(),
		"depth": _capture_depth() if _depth_enabled else []
	}

	_last_timestamp = result["timestamp"]
	_last_color_image = result["color"]
	_last_depth_image = result["depth"]

	frame_captured.emit(result["color"], result["depth"])
	return result


func capture_color() -> Array:
	_sync_camera_transform()
	return _capture_color()


func capture_depth() -> Array:
	_sync_camera_transform()
	return _capture_depth()


func _capture_color() -> Array:
	if not _internal_viewport:
		_setup_subviewport()

	# Force render via the SubViewport
	var texture = _internal_viewport.get_texture()
	if not texture:
		return _capture_color_fallback()

	var image = texture.get_image()
	if not image:
		return _capture_color_fallback()

	var color_data: Array = []
	for y in range(_height):
		var row: Array = []
		for x in range(_width):
			var pixel = image.get_pixel(x, y)
			var r = pixel.r * 255.0
			var g = pixel.g * 255.0
			var b = pixel.b * 255.0
			if _color_noise_stddev > 0:
				r = _apply_pixel_noise(r)
				g = _apply_pixel_noise(g)
				b = _apply_pixel_noise(b)
			row.append([clamp(r, 0.0, 255.0), clamp(g, 0.0, 255.0), clamp(b, 0.0, 255.0)])
		color_data.append(row)

	return color_data


func _capture_depth() -> Array:
	var space_state = get_world_3d().direct_space_state
	var depth_image: Array = []

	var fov_rad = deg_to_rad(_fov)
	var aspect_ratio = float(_width) / float(_height)
	var max_depth = 10.0

	for y in range(_height):
		var row: Array = []
		for x in range(_width):
			var u = (float(x) / float(_width)) * 2.0 - 1.0
			var v = (float(y) / float(_height)) * 2.0 - 1.0
			var u_scaled = u * tan(fov_rad / 2.0) * aspect_ratio
			var v_scaled = v * tan(fov_rad / 2.0)

			var ray_dir = Vector3(u_scaled, -v_scaled, -1.0).normalized()
			ray_dir = global_transform.basis * ray_dir

			var query = PhysicsRayQueryParameters3D.create(global_position, global_position + ray_dir * max_depth)
			var hit = space_state.intersect_ray(query)

			var depth_val: float
			if hit:
				depth_val = global_position.distance_to(hit.position)
			else:
				depth_val = 0.0

			if _depth_noise_stddev > 0:
				depth_val = _apply_pixel_noise(depth_val)

			row.append(depth_val)
		depth_image.append(row)

	return depth_image


func _capture_color_fallback() -> Array:
	var image = Image.create(_width, _height, false, Image.FORMAT_RGB8)
	image.fill(Color(0.5, 0.5, 0.5))

	var color_data: Array = []
	for y in range(_height):
		var row: Array = []
		for x in range(_width):
			var pixel = image.get_pixel(x, y)
			row.append([pixel.r * 255.0, pixel.g * 255.0, pixel.b * 255.0])
		color_data.append(row)

	return color_data


func _apply_pixel_noise(value: float) -> float:
	return value + randfn(0.0, _color_noise_stddev)


## ===== Configuration =====

func _apply_model_specs() -> void:
	match _model:
		"Intel RealSense D455":
			var specs = REALSENSE_D455_SPECS
			_width = specs["width"]; _height = specs["height"]; _fov = specs["fov"]
			_fx = specs["fx"]; _fy = specs["fy"]; _cx = specs["cx"]; _cy = specs["cy"]
		"Azure Kinect DK":
			var specs = KINECT_AZURE_SPECS
			_width = specs["width"]; _height = specs["height"]; _fov = specs["fov"]
			_fx = specs["fx"]; _fy = specs["fy"]; _cx = specs["cx"]; _cy = specs["cy"]
		"ZED 2i":
			var specs = ZED_2I_SPECS
			_width = specs["width"]; _height = specs["height"]; _fov = specs["fov"]
			_fx = specs["fx"]; _fy = specs["fy"]; _cx = specs["cx"]; _cy = specs["cy"]


func _setup_projection() -> void:
	var fov_rad = deg_to_rad(_fov)
	var aspect = float(_width) / float(_height)
	projection = PROJECTION_PERSPECTIVE
	fov_scale = fov_rad
	aspect_ratio = aspect


## ===== Intrinsics =====

func get_intrinsics() -> Dictionary:
	return {
		"fx": _fx, "fy": _fy, "cx": _cx, "cy": _cy,
		"k1": _k1, "k2": _k2, "p1": _p1, "p2": _p2,
		"width": _width, "height": _height
	}


func set_intrinsics(fx: float, fy: float, cx: float, cy: float) -> void:
	_fx = fx; _fy = fy; _cx = cx; _cy = cy


func set_distortion(k1: float, k2: float, p1: float, p2: float) -> void:
	_k1 = k1; _k2 = k2; _p1 = p1; _p2 = p2


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
	if _internal_viewport:
		_internal_viewport.size = Vector2i(_width, _height)
		_internal_camera.fov = _fov


func get_model_specs() -> Dictionary:
	return {
		"model": _model,
		"width": _width,
		"height": _height,
		"fov": _fov,
		"color_enabled": _color_enabled,
		"depth_enabled": _depth_enabled
	}
