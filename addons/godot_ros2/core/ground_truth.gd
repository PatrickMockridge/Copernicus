# ground_truth.gd
# Ground truth odometry publisher

class_name GroundTruth

var _robot_name: String
var _publisher: Publisher


func _init(robot_name: String) -> void:
	_robot_name = robot_name


func setup_publisher(ros2_node: ROS2Node) -> void:
	_publisher = ros2_node.create_publisher("/%s/odom" % _robot_name, "nav_msgs/Odometry")


func update(robot: RobotModel) -> void:
	if _publisher:
		var pose = robot.get_pose()
		var msg = NavMsgs.create_odometry_from_gd(
			StdMsgs.create_header_now("map"),
			_robot_name,
			pose["position"],
			pose["orientation"],
			Vector3.ZERO,  # linear velocity
			Vector3.ZERO   # angular velocity
		)
		_publisher.publish(msg)