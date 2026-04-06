# camera_sensor.gd
# Camera sensor

class_name CameraSensor
extends Sensor

var _fov: float = 1.047  # ~60 degrees
var _near: float = 0.1
var _far: float = 100.0
var _width: int = 640
var _height: int = 480
var _publish_topic: String = "image_raw"
var _compression: String = "none"  # none, jpeg, png


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


func get_projection_matrix() -> Projection:
	return Projection()


func render_viewport(camera: Camera3D) -> Image:
	var viewport = camera.get_viewport()
	var texture = viewport.get_texture()
	var image = texture.get_image()
	return image