# imu_sensor.gd
# IMU sensor

class_name ImuSensor
extends Sensor

var _publish_topic: String = "imu"
var _orientation: Quaternion = Quaternion.IDENTITY
var _angular_velocity: Vector3 = Vector3.ZERO
var _linear_acceleration: Vector3 = Vector3.ZERO
var _attached_body: RigidBody3D
var _bias_drift: Vector3 = Vector3.ZERO
var _random_walk: float = 0.001


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


func attach_to_rigid_body(body: RigidBody3D) -> void:
	_attached_body = body


func poll_from_body() -> void:
	if not _attached_body or not is_instance_valid(_attached_body):
		return
	_orientation = _attached_body.quaternion
	_angular_velocity = _attached_body.angular_velocity
	var accel = _attached_body.linear_velocity  # Raw velocity, add gravity later
	accel.y -= 9.81  # Gravity compensation to get proper acceleration
	if _noise_enabled:
		for i in range(3):
			_bias_drift[i] += randfn(0.0, _random_walk)
		accel = Vector3(
			Sensor.gaussian_noise(accel.x, _bias_drift.x, 0.01),
			Sensor.gaussian_noise(accel.y, _bias_drift.y, 0.01),
			Sensor.gaussian_noise(accel.z, _bias_drift.z, 0.01)
		)
	_linear_acceleration = accel


func get_imu_message(header: Dictionary) -> Dictionary:
	return SensorMsgs.create_imu_from_gd(
		header,
		_orientation,
		_angular_velocity,
		_linear_acceleration
	)