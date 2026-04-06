# contact_manager.gd
# Contact manager component

class_name ContactManager

var _contacts: Array = []


func _init() -> void:
	pass


func reset() -> void:
	_contacts.clear()


func add_contact(body1: String, body2: String, position: Vector3, normal: Vector3) -> void:
	_contacts.append({
		"body1": body1,
		"body2": body2,
		"position": position,
		"normal": normal
	})


func get_contacts() -> Array:
	return _contacts


func get_contacts_for_body(body: String) -> Array:
	var result: Array = []
	for c in _contacts:
		if c["body1"] == body or c["body2"] == body:
			result.append(c)
	return result