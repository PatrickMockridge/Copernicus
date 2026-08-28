# geometry_msgs.gd
# Helpers for building geometry_msgs-compatible dictionaries.

class_name GeometryMsgs


static func create_vector3(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func create_quaternion(q: Quaternion) -> Dictionary:
	return {"x": q.x, "y": q.y, "z": q.z, "w": q.w}


static func create_twist(linear: Vector3, angular: Vector3) -> Dictionary:
	return {
		"linear": create_vector3(linear),
		"angular": create_vector3(angular)
	}


static func create_wrench(force: Vector3, torque: Vector3) -> Dictionary:
	return {
		"force": create_vector3(force),
		"torque": create_vector3(torque)
	}
