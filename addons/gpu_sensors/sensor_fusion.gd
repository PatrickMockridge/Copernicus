# sensor_fusion.gd
# Multi-sensor fusion for robots
# Combines LIDAR, camera, IMU, GPS into unified perception

class_name SensorFusion
extends Node3D


## ===== Sensor References =====

var _lidar: RTXLidar = null
var _camera: RTXCamera = null
var _imu: Node3D = null
var _gps: Node3D = null


## ===== Fusion Configuration =====

var _fusion_mode: String = "kalman"  # kalman, extended_kalman, particle
var _update_rate: float = 100.0  # Hz


## ===== State Estimation =====

var _position: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _orientation: Quaternion = Quaternion.IDENTITY

var _position_covariance: float = 0.1
var _velocity_covariance: float = 0.1


## ===== History =====

var _position_history: Array = []
var _velocity_history: Array = []
var _max_history: int = 100


## ===== Signals =====

signal state_updated(position: Vector3, velocity: Vector3, orientation: Quaternion)
signal sensor_error(message: String)


## ===== Initialization =====

func _ready() -> void:
	_set_process(true)


func _process(delta: float) -> void:
	# Fuse sensor data at update_rate
	if _update_rate > 0:
		var interval = 1.0 / _update_rate
		# Run fusion periodically would need a timer, simplified here
		pass


func initialize(config: Dictionary) -> bool:
	_fusion_mode = config.get("fusion_mode", _fusion_mode)
	_update_rate = config.get("update_rate", _update_rate)

	return true


## ===== Sensor Registration =====

func set_lidar(lidar: RTXLidar) -> void:
	_lidar = lidar
	if lidar:
		lidar.scan_complete.connect(_on_lidar_scan)


func set_camera(camera: RTXCamera) -> void:
	_camera = camera
	if camera:
		camera.frame_captured.connect(_on_camera_frame)


func set_imu(imu: Node3D) -> void:
	_imu = imu


func set_gps(gps: Node3D) -> void:
	_gps = gps


## ===== Fusion Methods =====

func fuse_sensors() -> Dictionary:
	# Perform sensor fusion
	var result = {
		"position": _position,
		"velocity": _velocity,
		"orientation": _orientation,
		"timestamp": Time.get_unix_time_from_system()
	}

	match _fusion_mode:
		"kalman":
			result = _kalman_fusion()
		"extended_kalman":
			result = _extended_kalman_fusion()
		"particle":
			result = _particle_fusion()

	state_updated.emit(result["position"], result["velocity"], result["orientation"])
	return result


func _kalman_fusion() -> Dictionary:
	# Simple Kalman filter for state estimation
	var measured_position = _position
	var measured_velocity = _velocity

	# If GPS available, use it
	if _gps:
		measured_position = _gps.get_position()

	# If LIDAR available, use it for position correction
	if _lidar:
		var point_cloud = _lidar.get_point_cloud()
		if not point_cloud.is_empty():
			# Simple centroid-based position
			var centroid = _compute_point_cloud_centroid(point_cloud)
			if centroid != Vector3.ZERO:
				measured_position = centroid

	# Kalman gain
	var k_pos = _position_covariance / (_position_covariance + _velocity_covariance)
	var k_vel = _velocity_covariance / (_position_covariance + _velocity_covariance)

	_position = _position + k_pos * (measured_position - _position)
	_velocity = _velocity + k_vel * (measured_velocity - _velocity)

	# Update history
	_position_history.append(_position)
	_velocity_history.append(_velocity)
	_trim_history()

	return {
		"position": _position,
		"velocity": _velocity,
		"orientation": _orientation
	}


func _extended_kalman_fusion() -> Dictionary:
	# Extended Kalman filter for nonlinear systems
	return _kalman_fusion()  # Simplified - would need proper EKF implementation


func _particle_fusion() -> Dictionary:
	# Particle filter (simplified)
	return {
		"position": _position,
		"velocity": _velocity,
		"orientation": _orientation
	}


func _compute_point_cloud_centroid(point_cloud: Array) -> Vector3:
	if point_cloud.is_empty():
		return Vector3.ZERO

	var sum = Vector3.ZERO
	var count = 0

	for point in point_cloud:
		if point.size() >= 3:
			sum += Vector3(point[0], point[1], point[2])
			count += 1

	if count > 0:
		return sum / count
	return Vector3.ZERO


## ===== Odometry =====

func compute_odometry(delta: float) -> Dictionary:
	# Dead reckoning odometry
	var odometry = {
		"position": _position,
		"velocity": _velocity,
		"acceleration": Vector3.ZERO,
		"timestamp": Time.get_unix_time_from_system()
	}

	# If IMU available, use for velocity/acceleration
	if _imu:
		var imu_data = _imu.get_linear_acceleration()
		if imu_data.size() >= 3:
			var acceleration = Vector3(imu_data[0], imu_data[1], imu_data[2])
			_velocity += acceleration * delta
			_position += _velocity * delta
			odometry["acceleration"] = acceleration

	return odometry


## ===== SLAM Integration =====

func get_map_data() -> Dictionary:
	# Get map data from LIDAR for SLAM
	var map_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"position": _position,
		"point_cloud": [],
		"occupancy_grid": []
	}

	if _lidar:
		map_data["point_cloud"] = _lidar.get_point_cloud()
		map_data["range_image"] = _lidar.get_range_image()

	return map_data


## ===== State Access =====

func get_position() -> Vector3:
	return _position


func get_velocity() -> Vector3:
	return _velocity


func get_orientation() -> Quaternion:
	return _orientation


func get_state() -> Dictionary:
	return {
		"position": _position,
		"velocity": _velocity,
		"orientation": _orientation,
		"position_covariance": _position_covariance,
		"velocity_covariance": _velocity_covariance
	}


func set_state(position: Vector3, velocity: Vector3, orientation: Quaternion) -> void:
	_position = position
	_velocity = velocity
	_orientation = orientation


## ===== Configuration =====

func set_fusion_mode(mode: String) -> void:
	if mode in ["kalman", "extended_kalman", "particle"]:
		_fusion_mode = mode


func set_update_rate(rate: float) -> void:
	_update_rate = rate


## ===== History =====

func _trim_history() -> void:
	if _position_history.size() > _max_history:
		_position_history.pop_front()
	if _velocity_history.size() > _max_history:
		_velocity_history.pop_front()


func get_position_history() -> Array:
	return _position_history.duplicate()


func get_velocity_history() -> Array:
	return _velocity_history.duplicate()


## ===== Signal Handlers =====

func _on_lidar_scan(point_cloud: Array) -> void:
	# LIDAR scan completed
	pass


func _on_camera_frame(color: Array, depth: Array) -> void:
	# Camera frame captured
	pass
