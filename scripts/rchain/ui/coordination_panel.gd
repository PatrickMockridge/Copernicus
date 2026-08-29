class_name CoordinationPanel
extends Control
## Coordination UI: registry browser, capability transfer, job publish/claim, channels.

var _status: Label
var _registry_output: TextEdit
var _name_input: LineEdit
var _robot_input: LineEdit
var _to_input: LineEdit
var _job_input: LineEdit
var _channel_input: LineEdit
var _coordination: CoordinationCore


func _ready() -> void:
	_coordination = MockCoordination.new()
	_setup_ui()


func _setup_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	v.add_child(header)
	var title := CopernicusTheme.make_heading("Coordination")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var backend_btn := Button.new()
	backend_btn.text = "Backend"
	backend_btn.tooltip_text = "Select coordination backend"
	backend_btn.pressed.connect(_on_backend_pressed)
	header.add_child(backend_btn)

	# registry
	v.add_child(CopernicusTheme.make_body("Register robot"))
	var reg_row := HBoxContainer.new()
	v.add_child(reg_row)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "robot name"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reg_row.add_child(_name_input)
	var reg_btn := Button.new()
	reg_btn.text = "Register"
	reg_btn.pressed.connect(_on_register)
	reg_row.add_child(reg_btn)
	var list_btn := Button.new()
	list_btn.text = "List Robots"
	list_btn.pressed.connect(_on_list)
	reg_row.add_child(list_btn)

	v.add_child(CopernicusTheme.make_separator())

	# capability transfer
	v.add_child(CopernicusTheme.make_body("Capability transfer"))
	var cap_row := HBoxContainer.new()
	v.add_child(cap_row)
	_robot_input = LineEdit.new()
	_robot_input.placeholder_text = "robot"
	_robot_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_row.add_child(_robot_input)
	_to_input = LineEdit.new()
	_to_input.placeholder_text = "to address"
	_to_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_row.add_child(_to_input)
	var issue_btn := Button.new()
	issue_btn.text = "Issue"
	issue_btn.pressed.connect(_on_issue)
	cap_row.add_child(issue_btn)
	var transfer_btn := Button.new()
	transfer_btn.text = "Transfer"
	transfer_btn.pressed.connect(_on_transfer)
	cap_row.add_child(transfer_btn)

	v.add_child(CopernicusTheme.make_separator())

	# jobs
	v.add_child(CopernicusTheme.make_body("Job"))
	var job_row := HBoxContainer.new()
	v.add_child(job_row)
	_job_input = LineEdit.new()
	_job_input.placeholder_text = "job id"
	_job_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job_row.add_child(_job_input)
	var pub_btn := Button.new()
	pub_btn.text = "Publish"
	pub_btn.pressed.connect(_on_publish_job)
	job_row.add_child(pub_btn)
	var claim_btn := Button.new()
	claim_btn.text = "Claim"
	claim_btn.pressed.connect(_on_claim_job)
	job_row.add_child(claim_btn)

	v.add_child(CopernicusTheme.make_separator())

	# channels
	v.add_child(CopernicusTheme.make_body("Channel"))
	var ch_row := HBoxContainer.new()
	v.add_child(ch_row)
	_channel_input = LineEdit.new()
	_channel_input.placeholder_text = "channel name"
	_channel_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch_row.add_child(_channel_input)
	var sub_btn := Button.new()
	sub_btn.text = "Subscribe"
	sub_btn.pressed.connect(_on_subscribe)
	ch_row.add_child(sub_btn)
	var emit_btn := Button.new()
	emit_btn.text = "Emit"
	emit_btn.pressed.connect(_on_emit)
	ch_row.add_child(emit_btn)

	_registry_output = TextEdit.new()
	_registry_output.custom_minimum_size.y = 160
	_registry_output.editable = false
	v.add_child(_registry_output)

	_status = CopernicusTheme.make_body("")
	v.add_child(_status)


func _on_backend_pressed() -> void:
	var selector = load("res://scenes/rchain/coordination_selector.tscn").instantiate()
	selector.backend_selected.connect(_on_backend_selected)
	add_child(selector)


func _on_backend_selected(backend_id: String) -> void:
	var backend = CoordinationSelector.create_backend(backend_id, {})
	if backend:
		_coordination = backend
		_status.text = "Backend: " + backend_id


func _on_register() -> void:
	var r: Result = _coordination.register_robot({"name": _name_input.text.strip_edges()})
	_status.text = "Register: " + ("ok" if r.is_ok() else r.get_error())


func _on_list() -> void:
	var r: Result = _coordination.list_robots()
	if r.is_ok():
		_registry_output.text = JSON.stringify(r.get_data(), "  ")
		_status.text = "Listed %d robots" % r.get_data().size()
	else:
		_status.text = "List error: " + r.get_error()


func _on_issue() -> void:
	var r: Result = _coordination.issue_capability(_robot_input.text.strip_edges())
	_status.text = "Issue: " + ("ok" if r.is_ok() else r.get_error())


func _on_transfer() -> void:
	var r: Result = _coordination.transfer_capability(_robot_input.text.strip_edges(), _to_input.text.strip_edges())
	_status.text = "Transfer: " + ("ok" if r.is_ok() else r.get_error())


func _on_publish_job() -> void:
	var job: Dictionary = {"id": _job_input.text.strip_edges(), "spec": {}}
	var r: Result = _coordination.publish_job(job)
	_status.text = "Publish: " + ("ok" if r.is_ok() else r.get_error())


func _on_claim_job() -> void:
	var r: Result = _coordination.claim_job(_job_input.text.strip_edges(), _robot_input.text.strip_edges())
	_status.text = "Claim: " + ("ok" if r.is_ok() else r.get_error())


func _on_subscribe() -> void:
	var r: Result = _coordination.subscribe_channel(_channel_input.text.strip_edges())
	_status.text = "Subscribe: " + ("ok" if r.is_ok() else r.get_error())


func _on_emit() -> void:
	var r: Result = _coordination.emit_event(_channel_input.text.strip_edges(), {"hello": "world"})
	_status.text = "Emit: " + ("ok" if r.is_ok() else r.get_error())
