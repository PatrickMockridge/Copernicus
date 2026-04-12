# camera_sensor.gd
# Camera sensor with lens distortion support

class_name CameraSensor
extends Sensor

var _fov: float = 1.047  # ~60 degrees
var _near: float = 0.1
var _far: float = 100.0
var _width: int = 640
var _height: int = 480
var _publish_topic: String = "image_raw"
var _compression: String = "none"  # none, jpeg, png

## Lens distortion parameters (Brown-Conrady model)
var _distortion_enabled: bool = false
var _k1: float = 0.0  # Radial distortion coefficient 1
var _k2: float = 0.0  # Radial distortion coefficient 2
var _p1: float = 0.0  # Tangential distortion coefficient 1
var _p2: float = 0.0  # Tangential distortion coefficient 2
var _k3: float = 0.0  # Radial distortion coefficient 3
var _cx_offset: float = 0.0  # Principal point offset X
var _cy_offset: float = 0.0  # Principal point offset Y

## Noise parameters
var _noise_stddev: float = 0.0
var _salt_pepper_prob: float = 0.0


func _init(name: String) -> void:
	super(name)
	_frame_id = name


func set_fov(fov: float) -> void:
	_fov = fov


func set_near(near: float) -> void:
	_near = near


func set_far(far: float) -> void:
	_far = far


func set_resolution(width: int, height: int) -> void:
	_width = width
	_height = height


func set_publish_topic(topic: String) -> void:
	_publish_topic = topic


func configure(params: Dictionary) -> void:
	super.configure(params)
	if "fov" in params:
		set_fov(params["fov"])
	if "near" in params:
		set_near(params["near"])
	if "far" in params:
		set_far(params["far"])
	if "width" in params and "height" in params:
		set_resolution(params["width"], params["height"])
	if "topic" in params:
		set_publish_topic(params["topic"])
	if "lens_distortion" in params:
		_enable_lens_distortion(params["lens_distortion"])
	if "noise_stddev" in params:
		_noise_stddev = params["noise_stddev"]
	if "salt_pepper_prob" in params:
		_salt_pepper_prob = params["salt_pepper_prob"]


func _enable_lens_distortion(params: Dictionary) -> void:
	_distortion_enabled = true
	_k1 = params.get("k1", 0.0)
	_k2 = params.get("k2", 0.0)
	_k3 = params.get("k3", 0.0)
	_p1 = params.get("p1", 0.0)
	_p2 = params.get("p2", 0.0)
	_cx_offset = params.get("cx_offset", 0.0)
	_cy_offset = params.get("cy_offset", 0.0)


func get_projection_matrix() -> Projection:
	return Projection()


func apply_lens_distortion(point: Vector2) -> Vector2:
	"""Apply Brown-Conrady lens distortion model to a normalized 2D point"""
	if not _distortion_enabled:
		return point

	# Center point and apply offset
	var x = point.x + _cx_offset
	var y = point.y + _cy_offset

	# Apply radial distortion
	var r2 = x * x + y * y
	var radial = 1.0 + r2 * (_k1 + _k2 * r2 + _k3 * r2 * r2)

	# Apply tangential distortion
	var tx = 2.0 * _p1 * x * y + _p2 * (r2 + 2.0 * x * x)
	var ty = _p1 * (r2 + 2.0 * y * y) + 2.0 * _p2 * x * y

	# Compute distorted point
	var xd = radial * x + tx
	var yd = radial * y + ty

	return Vector2(xd - _cx_offset, yd - _cy_offset)


func apply_noise_to_pixel(value: float) -> float:
	"""Apply noise to a single pixel value (0-255 range assumed)"""
	if _noise_stddev > 0:
		value = Sensor.gaussian_noise(value, 0.0, _noise_stddev)
	if _salt_pepper_prob > 0:
		if randf() < _salt_pepper_prob:
			return 0.0
		elif randf() < _salt_pepper_prob:
			return 255.0
	return clamp(value, 0.0, 255.0)


func render_viewport(camera: Camera3D) -> Image:
	var viewport = camera.get_viewport()
	var texture = viewport.get_texture()
	var image = texture.get_image()
	return image


func get_distortion_params() -> Dictionary:
	return {
		"k1": _k1,
		"k2": _k2,
		"k3": _k3,
		"p1": _p1,
		"p2": _p2,
		"cx_offset": _cx_offset,
		"cy_offset": _cy_offset,
		"enabled": _distortion_enabled
	}