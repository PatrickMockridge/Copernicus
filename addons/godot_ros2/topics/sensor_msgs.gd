# sensor_msgs.gd
# Sensor message types for ROS 2

class_name SensorMsgs

# ===== Image =====

static func create_image(
	header: Dictionary,
	height: int,
	width: int,
	encoding: String,
	is_bigendian: int,
	step: int,
	data: PackedByteArray
) -> Dictionary:
	return {
		"header": header,
		"height": height,
		"width": width,
		"encoding": encoding,
		"is_bigendian": is_bigendian,
		"step": step,
		"data": data
	}


static func create_image_from_gdtex(texture: ImageTexture, header: Dictionary) -> Dictionary:
	var image = texture.get_image()
	var width = image.get_width()
	var height = image.get_height()

	var data = PackedByteArray()
	for y in range(height):
		for x in range(width):
			var pixel = image.get_pixel(x, y)
			data.append(int(pixel.r * 255) & 0xFF)
			data.append(int(pixel.g * 255) & 0xFF)
			data.append(int(pixel.b * 255) & 0xFF)
			data.append(int(pixel.a * 255) & 0xFF)

	return create_image(header, height, width, "rgba8", 0, width * 4, data)


# ===== CompressedImage =====

static func create_compressed_image(
	header: Dictionary,
	format: String,
	data: PackedByteArray
) -> Dictionary:
	return {
		"header": header,
		"format": format,
		"data": data
	}


# ===== PointCloud2 =====

static func create_pointcloud2(
	header: Dictionary,
	height: int,
	width: int,
	fields: Array,
	is_bigendian: int,
	point_step: int,
	row_step: int,
	data: PackedByteArray,
	is_dense: bool
) -> Dictionary:
	return {
		"header": header,
		"height": height,
		"width": width,
		"fields": fields,
		"is_bigendian": is_bigendian,
		"point_step": point_step,
		"row_step": row_step,
		"data": data,
		"is_dense": is_dense
	}


static func create_pointcloud2_from_points(header: Dictionary, points: Array) -> Dictionary:
	# XYZ32F format
	var fields = [
		{"name": "x", "offset": 0, "datatype": 7, "count": 1},  # FLOAT32
		{"name": "y", "offset": 4, "datatype": 7, "count": 1},
		{"name": "z", "offset": 8, "datatype": 7, "count": 1}
	]

	var data = PackedByteArray()
	for p in points:
		var v = p if p is Vector3 else Vector3.ZERO
		var x_bytes = var_to_bytes(v.x)
		var y_bytes = var_to_bytes(v.y)
		var z_bytes = var_to_bytes(v.z)
		data.append_array(x_bytes)
		data.append_array(y_bytes)
		data.append_array(z_bytes)

	return {
		"header": header,
		"height": 1,
		"width": points.size(),
		"fields": fields,
		"is_bigendian": false,
		"point_step": 12,
		"row_step": 12 * points.size(),
		"data": data,
		"is_dense": true
	}


# ===== LaserScan =====

static func create_laserscan(
	header: Dictionary,
	angle_min: float,
	angle_max: float,
	angle_increment: float,
	time_increment: float,
	scan_time: float,
	range_min: float,
	range_max: float,
	ranges: Array,
	intensities: Array
) -> Dictionary:
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


# ===== Imu =====

static func create_imu(
	header: Dictionary,
	orientation: Dictionary,
	orientation_covariance: Array,
	angular_velocity: Dictionary,
	angular_velocity_covariance: Array,
	linear_acceleration: Dictionary,
	linear_acceleration_covariance: Array
) -> Dictionary:
	return {
		"header": header,
		"orientation": orientation,
		"orientation_covariance": orientation_covariance,
		"angular_velocity": angular_velocity,
		"angular_velocity_covariance": angular_velocity_covariance,
		"linear_acceleration": linear_acceleration,
		"linear_acceleration_covariance": linear_acceleration_covariance
	}


static func create_imu_from_gd(
	header: Dictionary,
	orientation: Quaternion,
	angular_velocity: Vector3,
	linear_acceleration: Vector3
) -> Dictionary:
	var zero_cov = Array()
	zero_cov.resize(9)
	zero_cov.fill(0.0)
	return create_imu(
		header,
		GeometryMsgs.create_quaternion(orientation),
		zero_cov,
		GeometryMsgs.create_vector3(angular_velocity),
		zero_cov,
		GeometryMsgs.create_vector3(linear_acceleration),
		zero_cov
	)


# ===== NavSatFix =====

static func create_navsatfix(
	header: Dictionary,
	latitude: float,
	longitude: float,
	altitude: float
) -> Dictionary:
	return {
		"header": header,
		"latitude": latitude,
		"longitude": longitude,
		"altitude": altitude
	}


# ===== Range =====

static func create_range(
	header: Dictionary,
	min_range: float,
	max_range: float,
	field_of_view: float,
	radiation_type: int,
	range_value: float
) -> Dictionary:
	return {
		"header": header,
		"min_range": min_range,
		"max_range": max_range,
		"field_of_view": field_of_view,
		"radiation_type": radiation_type,
		"range": range_value
	}


# ===== Joy =====

static func create_joy(header: Dictionary, axes: Array, buttons: Array) -> Dictionary:
	return {
		"header": header,
		"axes": axes,
		"buttons": buttons
	}


# ===== JoyFeedback =====

static func create_joy_feedback(type: int, id: int, intensity: float) -> Dictionary:
	return {
		"type": type,
		"id": id,
		"intensity": intensity
	}
