# lidar_sensor.gd
# LIDAR sensor with beam divergence and realistic noise

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

## Beam divergence parameters (real LIDAR beams diverge over distance)
var _beam_divergence: float = 0.018  # ~1 degree typical for Velodyne-style LIDAR
var _range_stddev: float = 0.01  # Standard deviation for range noise

## Specific absorption (for penetrating glass/water)
var _surface_absorptivity: float = 0.0


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


func set_beam_divergence(angle: float) -> void:
	"""Set beam divergence angle in radians"""
	_beam_divergence = angle


func set_range_noise(stddev: float) -> void:
	"""Set range measurement noise standard deviation"""
	_range_stddev = stddev


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
	if "beam_divergence" in params:
		set_beam_divergence(params["beam_divergence"])
	if "range_noise" in params:
		set_range_noise(params["range_noise"])


func _apply_range_noise(range_value: float) -> float:
	"""Apply realistic range noise based on distance"""
	if range_value >= _range_max:
		return range_value

	# Range noise increases with distance squared (typical for LIDAR)
	var distance_factor = range_value * range_value * 0.0001
	var total_stddev = _range_stddev + distance_factor

	return Sensor.gaussian_noise(range_value, 0.0, total_stddev)


func _apply_beam_divergence(angle: float) -> float:
	"""Apply angular noise from beam divergence"""
	if _beam_divergence <= 0:
		return angle

	# Beam divergence adds angular uncertainty proportional to range
	var divergence_noise = randfn(0, _beam_divergence * 0.5)
	return angle + divergence_noise


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
	# Override in subclass to return actual ranges with noise applied
	return []


func _get_intensities() -> Array:
	# Override in subclass to return actual intensities
	return []


func get_beam_divergence() -> float:
	return _beam_divergence