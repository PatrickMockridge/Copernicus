# geometry_msgs.gd
# Common geometry message types

class_name GeometryMsgs

# ===== Twist =====

static func create_twist(linear: Vector3 = Vector3.ZERO, angular: Vector3 = Vector3.ZERO) -> Dictionary:
	return {
		"linear": create_vector3(linear),
		"angular": create_vector3(angular)
	}


static func create_twist_stamped(header: Dictionary, linear: Vector3, angular: Vector3) -> Dictionary:
	return {
		"header": header,
		"twist": create_twist(linear, angular)
	}


# ===== Vector3 =====

static func create_vector3(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func vector3_to_gd(v: Dictionary) -> Vector3:
	return Vector3(v.get("x", 0.0), v.get("y", 0.0), v.get("z", 0.0))


# ===== Point =====

static func create_point(p: Vector3) -> Dictionary:
	return {"x": p.x, "y": p.y, "z": p.z}


static func point_to_gd(p: Dictionary) -> Vector3:
	return Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0))


# ===== Pose =====

static func create_pose(position: Vector3, rotation: Quaternion) -> Dictionary:
	return {
		"position": create_point(position),
		"orientation": create_quaternion(rotation)
	}


static func create_pose_stamped(header: Dictionary, position: Vector3, rotation: Quaternion) -> Dictionary:
	return {
		"header": header,
		"pose": create_pose(position, rotation)
	}


# ===== Quaternion =====

static func create_quaternion(q: Quaternion) -> Dictionary:
	return {"x": q.x, "y": q.y, "z": q.z, "w": q.w}


static func quaternion_to_gd(q: Dictionary) -> Quaternion:
	return Quaternion(q.get("x", 0.0), q.get("y", 0.0), q.get("z", 0.0), q.get("w", 1.0))


# ===== Transform =====

static func create_transform(translation: Vector3, rotation: Quaternion) -> Dictionary:
	return {
		"translation": create_vector3(translation),
		"rotation": create_quaternion(rotation)
	}


static func create_transform_stamped(header: Dictionary, translation: Vector3, rotation: Quaternion) -> Dictionary:
	return {
		"header": header,
		"transform": create_transform(translation, rotation)
	}


# ===== Wrench =====

static func create_wrench(force: Vector3 = Vector3.ZERO, torque: Vector3 = Vector3.ZERO) -> Dictionary:
	return {
		"force": create_vector3(force),
		"torque": create_vector3(torque)
	}


# ===== Polygon =====

static func create_polygon(points: Array) -> Dictionary:
	var ros_points: Array = []
	for p in points:
		if p is Vector3:
			ros_points.append(create_point(p))
		else:
			ros_points.append(p)
	return {"points": ros_points}


# ===== Pose2D =====

static func create_pose2d(x: float, y: float, theta: float) -> Dictionary:
	return {"x": x, "y": y, "theta": theta}


# ===== PoseWithCovariance =====

static func create_pose_with_covariance(pose: Dictionary, covariance: Array) -> Dictionary:
	return {
		"pose": pose,
		"covariance": covariance
	}


# ===== TwistWithCovariance =====

static func create_twist_with_covariance(twist: Dictionary, covariance: Array) -> Dictionary:
	return {
		"twist": twist,
		"covariance": covariance
	}
