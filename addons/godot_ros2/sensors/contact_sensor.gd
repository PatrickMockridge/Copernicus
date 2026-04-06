# contact_sensor.gd
# Contact sensor

extends Sensor

var _publish_topic: String = "contact"
var _contacts: Array = []


func _init(name: String) -> void:
	 super(name)
	_frame_id = name


func set_publish_topic(topic: String) -> void:
	_publish_topic = topic


func add_contact(position: Vector3, normal: Vector3, depth: float) -> void:
	_contacts.append({
		"position": position,
		"normal": normal,
		"depth": depth
	})


func clear_contacts() -> void:
	_contacts.clear()


func has_contacts() -> bool:
	return not _contacts.is_empty()