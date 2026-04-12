# isaac_ros_bridge.gd
# Isaac ROS message types and bridge
# Provides native support for Isaac ROS messages and services

class_name IsaacROS
extends RefCounted


## ===== Configuration =====

var _node_name: String = "godot_isaac_ros"
var _initialized: bool = false


## ===== Isaac ROS Message Types =====

## Supported Isaac ROS packages
enum IsaacPackage {
	CLEARING = 0,
	HOMING = 1,
	MOVEIT = 2,
	NAV2 = 3,
	CAN_BUS = 4,
	JOYSTICK = 5,
	APRIL_TAGS = 6,
	VOXEL_MAP = 7
}


## ===== Static Methods =====

static func is_isaac_available() -> bool:
	# Check if isaac_ros packages are available
	var result = OS.execute("ros2", ["pkg", "list"], true)
	if result[0] == OK:
		var output = result[1]
		return output.contains("isaac_ros") or output.contains("navigation2")
	return false


static func get_isaac_packages() -> Array:
	var result = OS.execute("ros2", ["pkg", "list"], true)
	if result[0] == OK:
		var output = result[1]
		var packages = []
		for line in output.split("\n"):
			if "isaac" in line.to_lower():
				packages.append(line.strip_edges())
		return packages
	return []


## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_node_name = config.get("node_name", "godot_isaac_ros")
	_initialized = true
	return true


func shutdown() -> void:
	_initialized = false


## ===== Isaac ROS Messages =====

## Create PoseStamped message (geometry_msgs)
static func create_pose_stamped(position: Vector3, orientation: Quaternion, frame_id: String = "map") -> Dictionary:
	return {
		"header": {
			"stamp": {
				"sec": Time.get_datetime_dict_from_system()["unix_time"],
				"nanosec": 0
			},
			"frame_id": frame_id
		},
		"pose": {
			"position": {"x": position.x, "y": position.y, "z": position.z},
			"orientation": {"x": orientation.x, "y": orientation.y, "z": orientation.z, "w": orientation.w}
		}
	}


## Create Twist message (geometry_msgs)
static func create_twist(linear: Vector3, angular: Vector3) -> Dictionary:
	return {
		"linear": {"x": linear.x, "y": linear.y, "z": linear.z},
		"angular": {"x": angular.x, "y": angular.y, "z": angular.z}
	}


## Create JointState message (sensor_msgs)
static func create_joint_state(names: Array, positions: Array, velocities: Array = [], efforts: Array = []) -> Dictionary:
	var result = {
		"header": {
			"stamp": {
				"sec": Time.get_datetime_dict_from_system()["unix_time"],
				"nanosec": 0
			},
			"frame_id": ""
		},
		"name": names,
		"position": positions
	}

	if velocities.size() == names.size():
		result["velocity"] = velocities
	if efforts.size() == names.size():
		result["effort"] = efforts

	return result


## Create Path message (nav_msgs)
static func create_path(poses: Array) -> Dictionary:
	return {
		"header": {
			"stamp": {
				"sec": Time.get_datetime_dict_from_system()["unix_time"],
				"nanosec": 0
			},
			"frame_id": "map"
		},
		"poses": poses
	}


## Create OccupancyGrid message (nav_msgs)
static func create_occupancy_grid(width: int, height: int, data: Array, resolution: float, origin: Vector3) -> Dictionary:
	return {
		"header": {
			"stamp": {
				"sec": Time.get_datetime_dict_from_system()["unix_time"],
				"nanosec": 0
			},
			"frame_id": "map"
		},
		"info": {
			"width": width,
			"height": height,
			"resolution": resolution,
			"origin": {
				"position": {"x": origin.x, "y": origin.y, "z": origin.z},
				"orientation": {"x": 0, "y": 0, "z": 0, "w": 1}
			}
		},
		"data": data
	}


## ===== Isaac-specific Messages =====

## Create realsense camera info
static func create_camera_info(width: int, height: int, fx: float, fy: float, cx: float, cy: float) -> Dictionary:
	return {
		"header": {"stamp": {"sec": 0, "nanosec": 0}, "frame_id": "camera_optical_frame"},
		"width": width,
		"height": height,
		"intrinsic_matrix": [fx, 0, 0, 0, fy, 0, cx, cy, 1],
		"distortion_model": "plumb_bob",
		"d": [0.0, 0.0, 0.0, 0.0, 0.0],
		"k": [fx, 0, cx, 0, fy, cy, 0, 0, 1],
		"r": [1, 0, 0, 0, 1, 0, 0, 0, 1],
		"p": [fx, 0, cx, 0, 0, fy, cy, 0, 0, 0, 1, 0]
	}


## Create point cloud2
static func create_point_cloud(width: int, height: int, points: Array) -> Dictionary:
	return {
		"header": {"stamp": {"sec": 0, "nanosec": 0}, "frame_id": "map"},
		"height": height,
		"width": width,
		"fields": [
			{"name": "x", "offset": 0, "datatype": 7, "count": 1},  # FLOAT32
			{"name": "y", "offset": 4, "datatype": 7, "count": 1},
			{"name": "z", "offset": 8, "datatype": 7, "count": 1},
			{"name": "rgb", "offset": 12, "datatype": 7, "count": 1}
		],
		"is_bigendian": false,
		"point_step": 16,
		"row_step": width * 16,
		"data": points,
		"is_dense": true
	}


## ===== Isaac Navigation =====

## Create MoveIt planning request
static func create_moveit_request(group_name: String, target_pose: Dictionary) -> Dictionary:
	return {
		"group_name": group_name,
		"pose_stamped": target_pose,
		"planner_id": "RRTConnectkConfigDefault",
		"num_planning_attempts": 1,
		"allowed_planning_time": 5.0,
		"max_velocity_scaling_factor": 0.1,
		"max_acceleration_scaling_factor": 0.1
	}


## Create NavigateToPose goal (Nav2)
static func create_navigate_to_pose_goal(target_pose: Dictionary, behavior_tree: String = "") -> Dictionary:
	return {
		"pose": target_pose,
		"behavior_tree": behavior_tree
	}


## ===== Isaac Manipulation =====

## Create grasped message for gripper
static func create_grasped_message(gripper_state: bool, force: float) -> Dictionary:
	return {
		"gripper_state": gripper_state,  # true = closed, false = open
		"applied_force": force,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}


## Create joint trajectory goal
static func create_joint_trajectory_goal(joint_names: Array, points: Array) -> Dictionary:
	return {
		"joint_names": joint_names,
		"points": points
	}


## ===== Conversion Helpers =====

## Convert Godot Transform to Pose
static func transform_to_pose(transform: Transform3D) -> Dictionary:
	var basis = transform.basis
	var origin = transform.origin
	var quat = basis.get_quaternion()
	return create_pose_stamped(origin, quat)


## Convert Pose to Godot Transform
static func pose_to_transform(pose: Dictionary) -> Transform3D:
	var pos = pose.get("pose", {}).get("position", {})
	var orient = pose.get("pose", {}).get("orientation", {})

	var position = Vector3(pos.get("x", 0), pos.get("y", 0), pos.get("z", 0))
	var orientation = Quaternion(
		orient.get("x", 0),
		orient.get("y", 0),
		orient.get("z", 0),
		orient.get("w", 1)
	)

	return Transform3D(Basis(orientation), position)


## ===== Status =====

func get_status() -> Dictionary:
	return {
		"initialized": _initialized,
		"node_name": _node_name,
		"isaac_available": is_isaac_available(),
		"packages": get_isaac_packages()
	}