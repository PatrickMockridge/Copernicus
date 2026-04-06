# lidar_sensor.gd
# LIDAR sensor

class_name LidarSensor
extends Sensor

var _angle_min: float = -PI
var _angle_max: float = PI
var _angle_increment: float = 0.0174533  # ~1 degree
var _range_min: float = 0.1
var _range_max: float = 30.0
var _scan_time: float = 0.1
var _publish_topic: String = "scan"
var _ray_count: int = 360
var _hits: Array = []


func _init(name: String) -> void:
	super(name)
	_frame_id = name


func set_angle_range(angle_min: float, angle_max: float) -> void:
	_angle_min = angle_min
	_angle_max = angle_max


func set_increment(inc: float) -> void:
	_angle_increment = inc
	_ray_count = int((_angle_max - _angle_min) / _angle_increment)


func set_range_limits(min_range: float, max_range: float) -> void:
	_range_min = min_range
	_range_max = max_range


func set_scan_time(time: float) -> void:
	_scan_time = time


func set_publish_topic(topic: String) -> void:
	_publish_topic = topic


func configure(params: Dictionary) -> void:
	super.configure(params)
	if "angle_min" in params and "angle_max" in params:
		set_angle_range(params["angle_min"], params["angle_max"])
	if "range_min" in params and "range_max" in params:
		set_range_limits(params["range_min"], params["range_max"])
	if "increment" in params:
		set_increment(params["increment"])
	if "topic" in params:
		set_publish_topic(params["topic"])


func get_scan_message(header: Dictionary) -> Dictionary:
	return SensorMsgs.create_laserscan(
		header,
		_angle_min,
		_angle_max,
		_angle_increment,
		0.0,
		_scan_time,
		_range_min,
		_range_max,
		_get_ranges(),
		_get_intensities()
	)


func _get_ranges() -> Array:
	return []


func _get_intensities() -> Array:
	return []