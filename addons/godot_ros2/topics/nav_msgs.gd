# nav_msgs.gd
# Navigation message types for ROS 2

class_name NavMsgs

# ===== Odometry =====

static func create_odometry(
	header: Dictionary,
	child_frame_id: String,
	pose: Dictionary,
	twist: Dictionary
) -> Dictionary:
	return {
		"header": header,
		"child_frame_id": child_frame_id,
		"pose": create_pose_with_covariance_stamped(pose),
		"twist": create_twist_with_covariance_stamped(twist)
	}


static func create_odometry_from_gd(
	header: Dictionary,
	child_frame_id: String,
	position: Vector3,
	orientation: Quaternion,
	linear_velocity: Vector3,
	angular_velocity: Vector3
) -> Dictionary:
	var cov36 = Array()
	cov36.resize(36)
	cov36.fill(0.0)
	return {
		"header": header,
		"child_frame_id": child_frame_id,
		"pose": {
			"pose": {
				"position": GeometryMsgs.create_point(position),
				"orientation": GeometryMsgs.create_quaternion(orientation)
			},
			"covariance": cov36
		},
		"twist": {
			"twist": {
				"linear": GeometryMsgs.create_vector3(linear_velocity),
				"angular": GeometryMsgs.create_vector3(angular_velocity)
			},
			"covariance": cov36
		}
	}


# ===== Path =====

static func create_path(header: Dictionary, poses: Array, reference_frame: String = "map") -> Dictionary:
	return {
		"header": header,
		"poses": poses,
		"reference_frame": reference_frame
	}


static func create_path_from_gd(header: Dictionary, waypoints: Array) -> Dictionary:
	var poses: Array = []
	for wp in waypoints:
		if wp is Vector3:
			poses.append({
				"header": header,
				"pose": {
					"position": GeometryMsgs.create_point(wp),
					"orientation": GeometryMsgs.create_quaternion(Quaternion.IDENTITY)
				}
			})
		elif wp is Dictionary and "position" in wp:
			poses.append({"header": header, "pose": wp})
	return {
		"header": header,
		"poses": poses,
		"reference_frame": "map"
	}


# ===== OccupancyGrid =====

static func create_occupancygrid(
	header: Dictionary,
	info: Dictionary,
	data: Array
) -> Dictionary:
	return {
		"header": header,
		"info": info,
		"data": data
	}


static func create_map_info(
	width: int,
	height: int,
	resolution: float,
	origin: Dictionary
) -> Dictionary:
	return {
		"width": width,
		"height": height,
		"resolution": resolution,
		"origin": origin
	}


# ===== GetMap =====

static func create_get_map_response(map: Dictionary) -> Dictionary:
	return {"map": map}


# ===== LoadMap =====

static func create_load_map_request(map_url: String) -> Dictionary:
	return {"map_url": map_url}


static func create_load_map_response(result: int, map: Dictionary, message: String) -> Dictionary:
	return {
		"result": result,
		"map": map,
		"message": message
	}


# Helper functions
static func create_pose_with_covariance_stamped(pose: Dictionary) -> Dictionary:
	if "covariance" in pose:
		return pose
	var cov36 = Array()
	cov36.resize(36)
	cov36.fill(0.0)
	return {"pose": pose, "covariance": cov36}


static func create_twist_with_covariance_stamped(twist: Dictionary) -> Dictionary:
	if "covariance" in twist:
		return twist
	var cov36 = Array()
	cov36.resize(36)
	cov36.fill(0.0)
	return {"twist": twist, "covariance": cov36}
