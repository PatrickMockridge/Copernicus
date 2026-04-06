# force_torque_sensor.gd
# Force Torque sensor

extends Sensor

var _publish_topic: String = "ft"
var _force: Vector3 = Vector3.ZERO
var _torque: Vector3 = Vector3.ZERO


func _init(name: String) -> void:
	 super(name)
	_frame_id = name


func update_meas(force: Vector3, torque: Vector3) -> void:
	_force = force
	_torque = torque


func get_wrench_message(header: Dictionary) -> Dictionary:
	return {
		"header": header,
		"wrench": GeometryMsgs.create_wrench(_force, _torque)
	}