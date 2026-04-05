# tf2_msgs.gd
# TF2 message types

class_name TF2Msgs

# ===== TFMessage =====

static func create_tf_message(transforms: Array) -> Dictionary:
	return {"transforms": transforms}


static func create_tf_message_from_gd(transforms: Array) -> Dictionary:
	var ros_transforms: Array = []
	for t in transforms:
		if t is Dictionary:
			ros_transforms.append(t)
		elif t.size() >= 2:
			# (translation, rotation) tuple
			ros_transforms.append({
				"header": StdMsgs.create_header_now("world"),
				"child_frame_id": "",
				"transform": {
					"translation": GeometryMsgs.create_vector3(t[0]),
					"rotation": GeometryMsgs.create_quaternion(t[1])
				}
			})
	return create_tf_message(ros_transforms)


# ===== TransformStamped =====

static func create_transform_stamped(
	header: Dictionary,
	child_frame_id: String,
	translation: Vector3,
	rotation: Quaternion
) -> Dictionary:
	return {
		"header": header,
		"child_frame_id": child_frame_id,
		"transform": {
			"translation": GeometryMsgs.create_vector3(translation),
			"rotation": GeometryMsgs.create_quaternion(rotation)
		}
	}


# ===== LookupTransform =====

static func create_lookup_transform_request(
	target_frame: String,
	source_frame: String,
	time: Dictionary,
	rapid_time: Dictionary,
	fixed_frame: String
) -> Dictionary:
	return {
		"target_frame": target_frame,
		"source_frame": source_frame,
		"time": time,
		"rapid_time": rapid_time,
		"fixed_frame": fixed_frame
	}


# ===== PoseStamped =====

static func create_pose_stamped_from_gd(header: Dictionary, position: Vector3, rotation: Quaternion) -> Dictionary:
	return {
		"header": header,
		"pose": {
			"position": GeometryMsgs.create_point(position),
			"orientation": GeometryMsgs.create_quaternion(rotation)
		}
	}
