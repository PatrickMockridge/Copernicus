# sensor_fusion.gd
# Multi-sensor fusion for robots
# Extended Kalman Filter combining LIDAR, camera, IMU, GPS into unified state estimate

class_name SensorFusion
extends Node3D


## ===== Sensor References =====

var _lidar: RTXLidar = null
var _camera: RTXCamera = null
var _imu: Node3D = null
var _gps: Node3D = null


## ===== Fusion Configuration =====

var _fusion_mode: String = "kalman"
var _update_rate: float = 100.0
var _time_accum: float = 0.0


## ===== EKF State =====

# State vector: [px, py, pz, vx, vy, vz]
var _x: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
# Covariance matrix (6x6, row-major)
var _P: PackedFloat64Array
# Process noise (6x6 diagonal)
var _Q: PackedFloat64Array
# Measurement noise for position (3x3 diagonal)
var _R_pos: PackedFloat64Array = [0.01, 0.0, 0.0, 0.0, 0.01, 0.0, 0.0, 0.0, 0.01]
# Observation matrix for position (3x6)
var _H_pos: PackedFloat64Array = [
	1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
	0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
	0.0, 0.0, 1.0, 0.0, 0.0, 0.0
]

var _last_predict_time: float = 0.0


## ===== History =====

var _position_history: Array = []
var _velocity_history: Array = []
var _max_history: int = 100


## ===== Signals =====

signal state_updated(position: Vector3, velocity: Vector3, orientation: Quaternion)
signal sensor_error(message: String)


## ===== Initialization =====

func _ready() -> void:
	_init_covariances()
	_last_predict_time = Time.get_unix_time_from_system()


func _init_covariances() -> void:
	# Initialize P as identity * 0.1 (6x6)
	_P.resize(36)
	for i in range(6):
		_P[i * 6 + i] = 0.1

	# Initialize Q as small diagonal (process noise)
	_Q.resize(36)
	var q_pos = 0.001
	var q_vel = 0.01
	_Q[0] = q_pos; _Q[7] = q_pos; _Q[14] = q_pos
	_Q[21] = q_vel; _Q[28] = q_vel; _Q[35] = q_vel


func _process(delta: float) -> void:
	if _update_rate <= 0:
		return

	var now = Time.get_unix_time_from_system()
	if _last_predict_time == 0.0:
		_last_predict_time = now
		return

	var dt = now - _last_predict_time
	_last_predict_time = now

	# Run prediction at update_rate
	_predict(dt)


func initialize(config: Dictionary) -> bool:
	_fusion_mode = config.get("fusion_mode", _fusion_mode)
	_update_rate = config.get("update_rate", _update_rate)
	_init_covariances()
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


## ===== EKF Core =====

func _predict(dt: float) -> void:
	if dt <= 0.0 or dt > 0.5:
		return

	# Build state transition F (6x6): constant velocity model
	var F: PackedFloat64Array = []
	F.resize(36)
	for i in range(6):
		F[i * 6 + i] = 1.0
	F[3] = dt; F[10] = dt; F[17] = dt  # x += vx*dt, y += vy*dt, z += vz*dt

	# x = F @ x
	var new_x: PackedFloat64Array = []
	new_x.resize(6)
	for i in range(6):
		var s: float = 0.0
		for j in range(6):
			s += F[i * 6 + j] * _x[j]
		new_x[i] = s
	_x = new_x

	# P = F @ P @ F^T + Q
	# Step 1: FP = F @ P (6x6 @ 6x6)
	var FP: PackedFloat64Array = []
	FP.resize(36)
	for i in range(6):
		for k in range(6):
			var s: float = 0.0
			for j in range(6):
				s += F[i * 6 + j] * _P[j * 6 + k]
			FP[i * 6 + k] = s

	# Step 2: FPFt = FP @ F^T (6x6 @ 6x6)
	for i in range(6):
		for k in range(6):
			var s: float = 0.0
			for j in range(6):
				s += FP[i * 6 + j] * F[k * 6 + j]  # F^T(j,k) = F(k,j)
			_P[i * 6 + k] = s + _Q[i * 6 + k]


func _update_position(measured: Vector3) -> void:
	# EKF measurement update with position observation
	var z: PackedFloat64Array = [measured.x, measured.y, measured.z]

	# y = z - H @ x (innovation)
	var y: PackedFloat64Array = [0.0, 0.0, 0.0]
	for i in range(3):
		var pred: float = 0.0
		for j in range(6):
			pred += _H_pos[i * 6 + j] * _x[j]
		y[i] = z[i] - pred

	# P_Ht = P @ H^T (6x6 @ 6x3) = (6x3)
	var P_Ht: PackedFloat64Array = []
	P_Ht.resize(18)
	for i in range(6):
		for k in range(3):
			var s: float = 0.0
			for j in range(6):
				s += _P[i * 6 + j] * _H_pos[k * 6 + j]  # H^T(j,k) = H(k,j)
			P_Ht[i * 3 + k] = s

	# S = H @ P_Ht + R (3x3)
	var S: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in range(3):
		for k in range(3):
			var s: float = 0.0
			for j in range(6):
				s += _H_pos[i * 6 + j] * P_Ht[j * 3 + k]
			S[i * 3 + k] = s + _R_pos[i * 3 + k]

	# K = P_Ht @ inv(S) (6x3)
	var S_inv = _invert_3x3(S)
	var K: PackedFloat64Array = []
	K.resize(18)
	for i in range(6):
		for k in range(3):
			var s: float = 0.0
			for j in range(3):
				s += P_Ht[i * 3 + j] * S_inv[j * 3 + k]
			K[i * 3 + k] = s

	# x = x + K @ y
	for i in range(6):
		var correction: float = 0.0
		for j in range(3):
			correction += K[i * 3 + j] * y[j]
		_x[i] += correction

	# P = P - K @ H @ P = P - K @ (P_Ht)^T
	# K is 6x3, P_Ht is 6x3, so K @ P_Ht^T is 6x6
	for i in range(6):
		for k in range(6):
			var s: float = 0.0
			for j in range(3):
				s += K[i * 3 + j] * P_Ht[k * 3 + j]  # P_Ht^T(j,k) = P_Ht(k,j)
			_P[i * 6 + k] -= s

	# Update history
	_position_history.append(get_position())
	_velocity_history.append(get_velocity())
	_trim_history()


func _invert_3x3(M: PackedFloat64Array) -> PackedFloat64Array:
	var a = M[0]; var b = M[1]; var c = M[2]
	var d = M[3]; var e = M[4]; var f = M[5]
	var g = M[6]; var h = M[7]; var i = M[8]

	var det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
	if abs(det) < 1e-12:
		return [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]

	var inv_det = 1.0 / det
	return [
		(e * i - f * h) * inv_det,
		(c * h - b * i) * inv_det,
		(b * f - c * e) * inv_det,
		(f * g - d * i) * inv_det,
		(a * i - c * g) * inv_det,
		(c * d - a * f) * inv_det,
		(d * h - e * g) * inv_det,
		(b * g - a * h) * inv_det,
		(a * e - b * d) * inv_det
	]


## ===== Fusion Methods =====

func fuse_sensors() -> Dictionary:
	var result = {
		"position": get_position(),
		"velocity": get_velocity(),
		"orientation": _orientation,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Try to incorporate latest sensor data
	if _gps:
		_update_position(_gps.get_position())

	if _lidar:
		var point_cloud = _lidar.get_point_cloud()
		if not point_cloud.is_empty():
			var centroid = _compute_point_cloud_centroid(point_cloud)
			if centroid != Vector3.ZERO:
				_update_position(centroid)

	state_updated.emit(result["position"], result["velocity"], result["orientation"])
	return result


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
	var odometry = {
		"position": get_position(),
		"velocity": get_velocity(),
		"acceleration": Vector3.ZERO,
		"timestamp": Time.get_unix_time_from_system()
	}

	if _imu:
		var imu_data = _imu.get_linear_acceleration()
		if imu_data.size() >= 3:
			var acceleration = Vector3(imu_data[0], imu_data[1], imu_data[2])
			odometry["acceleration"] = acceleration
			# Update state with IMU acceleration
			_x[3] += acceleration.x * delta
			_x[4] += acceleration.y * delta
			_x[5] += acceleration.z * delta
			_x[0] += _x[3] * delta
			_x[1] += _x[4] * delta
			_x[2] += _x[5] * delta

	return odometry


## ===== SLAM Integration =====

func get_map_data() -> Dictionary:
	var map_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"position": get_position(),
		"point_cloud": [],
		"occupancy_grid": []
	}

	if _lidar:
		map_data["point_cloud"] = _lidar.get_point_cloud()
		map_data["range_image"] = _lidar.get_range_image()

	return map_data


## ===== State Access =====

func get_position() -> Vector3:
	return Vector3(_x[0], _x[1], _x[2])


func get_velocity() -> Vector3:
	return Vector3(_x[3], _x[4], _x[5])


var _orientation: Quaternion = Quaternion.IDENTITY


func get_orientation() -> Quaternion:
	return _orientation


func get_state() -> Dictionary:
	return {
		"position": get_position(),
		"velocity": get_velocity(),
		"orientation": _orientation,
		"covariance": _P.duplicate()
	}


func set_state(position: Vector3, velocity: Vector3, orientation: Quaternion) -> void:
	_x[0] = position.x; _x[1] = position.y; _x[2] = position.z
	_x[3] = velocity.x; _x[4] = velocity.y; _x[5] = velocity.z
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
	if point_cloud.is_empty():
		return
	var centroid = _compute_point_cloud_centroid(point_cloud)
	if centroid != Vector3.ZERO:
		# Higher measurement noise for LIDAR centroid
		var saved_R = _R_pos.duplicate()
		_R_pos = [0.05, 0.0, 0.0, 0.0, 0.05, 0.0, 0.0, 0.0, 0.05]
		_update_position(centroid)
		_R_pos = saved_R
		state_updated.emit(get_position(), get_velocity(), _orientation)


func _on_camera_frame(color: Array, depth: Array) -> void:
	# Visual odometry would go here. For now, treat as data available signal.
	# A full implementation would run feature tracking and call _update_position.
	pass
