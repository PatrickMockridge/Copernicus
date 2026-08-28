# sensor_msgs.gd
# Helpers for building sensor_msgs-compatible dictionaries.

class_name SensorMsgs


static func _cov9() -> Array:
	return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


static func create_imu_from_gd(header: Dictionary, orientation: Quaternion, angular_velocity: Vector3, linear_acceleration: Vector3) -> Dictionary:
	return {
		"header": header,
		"orientation": GeometryMsgs.create_quaternion(orientation),
		"orientation_covariance": _cov9(),
		"angular_velocity": GeometryMsgs.create_vector3(angular_velocity),
		"angular_velocity_covariance": _cov9(),
		"linear_acceleration": GeometryMsgs.create_vector3(linear_acceleration),
		"linear_acceleration_covariance": _cov9()
	}


static func create_navsatfix(header: Dictionary, latitude: float, longitude: float, altitude: float) -> Dictionary:
	return {
		"header": header,
		"status": {"status": 0, "service": 1},
		"latitude": latitude,
		"longitude": longitude,
		"altitude": altitude,
		"position_covariance": _cov9(),
		"position_covariance_type": 0
	}


static func create_laserscan(header: Dictionary, angle_min: float, angle_max: float, angle_increment: float, time_increment: float, scan_time: float, range_min: float, range_max: float, ranges: Array, intensities: Array) -> Dictionary:
	return {
		"header": header,
		"angle_min": angle_min,
		"angle_max": angle_max,
		"angle_increment": angle_increment,
		"time_increment": time_increment,
		"scan_time": scan_time,
		"range_min": range_min,
		"range_max": range_max,
		"ranges": ranges,
		"intensities": intensities
	}
