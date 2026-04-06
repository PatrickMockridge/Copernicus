# imu_sensor.gd
# IMU sensor

class_name ImuSensor
extends Sensor

var _publish_topic: String = "imu"
var _orientation: Quaternion = Quaternion.IDENTITY
var _angular_velocity: Vector3 = Vector3.ZERO
var _linear_acceleration: Vector3 = Vector3.ZERO


func _init(name: String) -> void:
	super(name)
	_frame_id = name


func set_publish_topic(topic: String) -> void:
	_publish_topic = topic


func configure(params: Dictionary) -> void:
	super.configure(params)
	if "topic" in params:
		set_publish_topic(params["topic"])


func update_meas(orientation: Quaternion, angular_vel: Vector3, linear_accel: Vector3) -> void:
	_orientation = orientation
	_angular_velocity = angular_vel
	_linear_acceleration = linear_accel


func get_imu_message(header: Dictionary) -> Dictionary:
	return SensorMsgs.create_imu_from_gd(
		header,
		_orientation,
		_angular_velocity,
		_linear_acceleration
	)