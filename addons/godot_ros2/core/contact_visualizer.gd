# contact_visualizer.gd
# Contact visualization plugin

extends SimulatorPlugin

var _contact_markers: Array = []


func _init(name: String = "ContactVisualizer") -> void:
	super(name)


func on_physics_step(delta: float) -> void:
	var contacts = _simulator.get_contact_manager().get_contacts()
	for contact in contacts:
		_create_contact_marker(contact)


func _create_contact_marker(contact: Dictionary) -> void:
	pass