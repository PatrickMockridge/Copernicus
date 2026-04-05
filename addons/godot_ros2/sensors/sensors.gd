# sensors.gd
# Sensor implementations

class_name Sensor

var _name: String
var _robot: Node3D
var _parent_node: Node3D
var _update_rate: float = 30.0
var _last_update: float = 0.0
var _enabled: bool = true
var _frame_id: String = ""
var _pose: Transform3D = Transform3D.IDENTITY
var _noise_enabled: bool = false
var _noise_params: Dictionary = {}


func _init(name: String) -> void:
	_name = name
	_parent_node = Node3D.new()
	_parent_node.set_name(name)


func _to_string() -> String:
	return "Sensor:%s" % _name


func get_name() -> String:
	return _name


func get_node() -> Node3D:
	return _parent_node


func set_robot(robot: Node3D) -> void:
	_robot = robot


func get_robot() -> Node3D:
	return _robot


func set_frame_id(frame: String) -> void:
	_frame_id = frame


func get_frame_id() -> String:
	return _frame_id


func set_update_rate(rate: float) -> void:
	_update_rate = rate


func get_update_rate() -> float:
	return _update_rate


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_enabled() -> bool:
	return _enabled


func set_pose(pose: Transform3D) -> void:
	_pose = pose
	_parent_node.set_transform(pose)


func get_pose() -> Transform3D:
	return _pose


func set_noise_enabled(enabled: bool) -> void:
	_noise_enabled = enabled


func configure(params: Dictionary) -> void:
	if "update_rate" in params:
		set_update_rate(params["update_rate"])
	if "frame_id" in params:
		set_frame_id(params["frame_id"])
	if "pose" in params:
		set_pose(params["pose"])
	if "noise" in params:
		_noise_enabled = true
		_noise_params = params["noise"]


func should_update(current_time: float) -> bool:
	if not _enabled:
		return false
	var period = 1.0 / _update_rate
	return (current_time - _last_update) >= period


func mark_updated(current_time: float) -> void:
	_last_update = current_time


func get_header() -> Dictionary:
	return StdMsgs.create_header_now(_frame_id if not _frame_id.is_empty() else _name)


func apply_noise(value: float, param_name: String) -> float:
	if not _noise_enabled:
		return value
	var mean = _noise_params.get(param_name + "_mean", 0.0)
	var stddev = _noise_params.get(param_name + "_stddev", 0.0)
	return value + randfn(mean, stddev)


# ===== Camera Sensor =====

class_name CameraSensor
extends Sensor

var _fov: float = 1.047  # ~60 degrees
var _near: float = 0.1
var _far: float = 100.0
var _width: int = 640
var _height: int = 480
var _publish_topic: String = "image_raw"
var _compression: String = "none"  # none, jpeg, png


func _init(name: String).super(name) -> void:
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
	return Projection.new()
	# Would compute perspective projection


func render_viewport(camera: Camera3D) -> Image:
	var viewport = camera.get_viewport()
	var texture = viewport.get_texture()
	var image = texture.get_image()
	return image


# ===== LIDAR Sensor =====

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


func _init(name: String).super(name) -> void:
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
	# Returns range measurements
	return []


func _get_intensities() -> Array:
	# Returns intensity measurements
	return []


# ===== IMU Sensor =====

class_name ImuSensor
extends Sensor

var _publish_topic: String = "imu"
var _orientation: Quaternion = Quaternion.IDENTITY
var _angular_velocity: Vector3 = Vector3.ZERO
var _linear_acceleration: Vector3 = Vector3.ZERO


func _init(name: String).super(name) -> void:
	_frame_id = name


func set_publish_topic(topic: String) -> void:
	_publish_topic = topic


func configure(params: Dictionary) -> void:
	super.configure(params)
	if "topic" in params:
		set_publish_topic(params["topic"])


func update测量(orientation: Quaternion, angular_vel: Vector3, linear_accel: Vector3) -> void:
	_orientation = orientation
	_angular_velocity = angular_vel
	_linear_acceleration = linear_accel


func get_imu_message(header: Dictionary) -> Dictionary:
	return SensorMsgs.create_imu_from_gd(
		header,
		_orientation,
		_angular_velocity,
		_linear_acceleration
	)


# ===== GPS Sensor =====

class_name GPSSensor
extends Sensor

var _publish_topic: String = "gps"
var _latitude: float = 0.0
var _longitude: float = 0.0
var _altitude: float = 0.0
var _origin_lat: float = 0.0
var _origin_lon: float = 0.0


func _init(name: String).super(name) -> void:
	_frame_id = name


func set_publish_topic(topic: String) -> void:
	_publish_topic = topic


func set_origin(lat: float, lon: float) -> void:
	_origin_lat = lat
	_origin_lon = lon


func configure(params: Dictionary) -> void:
	super.configure(params)
	if "topic" in params:
		set_publish_topic(params["topic"])
	if "origin_lat" in params and "origin_lon" in params:
		set_origin(params["origin_lat"], params["origin_lon"])


func update测量(position: Vector3) -> void:
	# Convert world position to lat/lon
	_latitude = _origin_lat + position.z * 0.00001
	_longitude = _origin_lon + position.x * 0.00001
	_altitude = position.y


func get_gps_message(header: Dictionary) -> Dictionary:
	return SensorMsgs.create_navsatfix(header, _latitude, _longitude, _altitude)


# ===== Force Torque Sensor =====

class_name ForceTorqueSensor
extends Sensor

var _publish_topic: String = "ft"
var _force: Vector3 = Vector3.ZERO
var _torque: Vector3 = Vector3.ZERO


func _init(name: String).super(name) -> void:
	_frame_id = name


func update测量(force: Vector3, torque: Vector3) -> void:
	_force = force
	_torque = torque


func get_wrench_message(header: Dictionary) -> Dictionary:
	return {
		"header": header,
		"wrench": GeometryMsgs.create_wrench(_force, _torque)
	}


# ===== Contact Sensor =====

class_name ContactSensor
extends Sensor

var _publish_topic: String = "contact"
var _contacts: Array = []


func _init(name: String).super(name) -> void:
	_frame_id = name


func set_publish_topic(topic: String) -> void:
	_publish_topic = topic


func add_contact(position: Vector3, normal: Vector3, depth: float) -> void:
	_contacts.append({
		"position": position,
		"normal": normal,
		"depth": depth
	})


func clear_contacts() -> void:
	_contacts.clear()


func has_contacts() -> bool:
	return not _contacts.is_empty()
