class_name CoordinationPanel
extends Control
## Coordination UI: registry browser, capability transfer, job publish/claim, channels.

# Preload backends so RChainCoordination registers with ModuleRegistry.
const MockCoordination = preload("res://scripts/coordination/mock_coordination.gd")
const RChainCoordination = preload("res://scripts/coordination/rchain_coordination.gd")

var _status: Label
var _registry_output: TextEdit
var _name_input: LineEdit
var _robot_input: LineEdit
var _to_input: LineEdit
var _job_input: LineEdit
var _channel_input: LineEdit
var _coordination: CoordinationCore


func _ready() -> void:
	_setup_coordination()
	_setup_ui()


func _setup_coordination() -> void:
	# Start on the mock (non-blocking); switch to the real backend + wire its
	# signals once a node is confirmed reachable (checked on a TaskRunner thread).
	_coordination = MockCoordination.new()
	var backend = ModuleRegistry.create("coordination", "RChainCoordination", {})
	if backend == null:
		_connect_signals()
		return
	RChainService.run_async(
		func() -> Variant: return backend.is_coordination_connected(),
		func(connected) -> void:
			_coordination = backend if connected else _coordination
			_connect_signals()
	)


## Subscribe to the backend's domain signals (domain-signal rule: signals are
## consumed, never left dangling). Some also advance the Workbench Loop.
func _connect_signals() -> void:
	if _coordination == null:
		return
	_coordination.robot_registered.connect(_on_robot_registered)
	_coordination.capability_granted.connect(func(robot: String, holder: String) -> void: _status.text = "Granted %s → %s" % [robot, holder])
	_coordination.capability_revoked.connect(func(robot: String) -> void: _status.text = "Revoked %s" % robot)
	_coordination.ownership_transferred.connect(func(robot: String, _from: String, to: String) -> void: _status.text = "Transferred %s → %s" % [robot, to])
	_coordination.job_published.connect(_on_job_published)
	_coordination.job_claimed.connect(func(job_id: String, robot: String) -> void: _status.text = "Claimed %s by %s" % [job_id, robot])
	_coordination.job_completed.connect(func(job_id: String, _result: Dictionary) -> void: _status.text = "Completed %s" % job_id)
	_coordination.channel_message.connect(_on_channel_message)
	_coordination.work_published.connect(func(job_id: String, _command: Dictionary) -> void: _status.text = "Work published: %s" % job_id)
	_coordination.work_settled.connect(_on_work_settled)
	_coordination.error_occurred.connect(func(message: String) -> void: _status.text = "Error: " + message)


func _setup_ui() -> void:
	var win := UiPanel.new().setup("Coordination")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)

	var v: VBoxContainer = win.body()

	var backend_btn := UiButton.new().setup("Backend", UiButton.Variant.SECONDARY)
	backend_btn.tooltip_text = "Select coordination backend"
	backend_btn.pressed.connect(_on_backend_pressed)
	win.title_actions().add_child(backend_btn)

	# registry
	v.add_child(UiSection.new().setup("Register robot"))
	var reg_row := HBoxContainer.new()
	v.add_child(reg_row)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "robot name"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reg_row.add_child(_name_input)
	var reg_btn := UiButton.new().setup("Register", UiButton.Variant.SECONDARY)
	reg_btn.pressed.connect(_on_register)
	reg_row.add_child(reg_btn)
	var list_btn := UiButton.new().setup("List Robots", UiButton.Variant.SECONDARY)
	list_btn.pressed.connect(_on_list)
	reg_row.add_child(list_btn)

	v.add_child(UiSeparator.new())

	# capability transfer
	v.add_child(UiSection.new().setup("Capability transfer"))
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
	var issue_btn := UiButton.new().setup("Issue", UiButton.Variant.SECONDARY)
	issue_btn.pressed.connect(_on_issue)
	cap_row.add_child(issue_btn)
	var transfer_btn := UiButton.new().setup("Transfer", UiButton.Variant.SECONDARY)
	transfer_btn.pressed.connect(_on_transfer)
	cap_row.add_child(transfer_btn)

	v.add_child(UiSeparator.new())

	# jobs
	v.add_child(UiSection.new().setup("Job"))
	var job_row := HBoxContainer.new()
	v.add_child(job_row)
	_job_input = LineEdit.new()
	_job_input.placeholder_text = "job id"
	_job_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job_row.add_child(_job_input)
	var pub_btn := UiButton.new().setup("Publish", UiButton.Variant.SECONDARY)
	pub_btn.pressed.connect(_on_publish_job)
	job_row.add_child(pub_btn)
	var claim_btn := UiButton.new().setup("Claim", UiButton.Variant.SECONDARY)
	claim_btn.pressed.connect(_on_claim_job)
	job_row.add_child(claim_btn)

	v.add_child(UiSeparator.new())

	# channels
	v.add_child(UiSection.new().setup("Channel"))
	var ch_row := HBoxContainer.new()
	v.add_child(ch_row)
	_channel_input = LineEdit.new()
	_channel_input.placeholder_text = "channel name"
	_channel_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch_row.add_child(_channel_input)
	var sub_btn := UiButton.new().setup("Subscribe", UiButton.Variant.SECONDARY)
	sub_btn.pressed.connect(_on_subscribe)
	ch_row.add_child(sub_btn)
	var emit_btn := UiButton.new().setup("Emit", UiButton.Variant.SECONDARY)
	emit_btn.pressed.connect(_on_emit)
	ch_row.add_child(emit_btn)

	_registry_output = TextEdit.new()
	_registry_output.custom_minimum_size.y = 160
	_registry_output.editable = false
	v.add_child(_registry_output)

	_status = UiLabel.new().setup("", UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
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
		_connect_signals()


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


# --- backend signal handlers ---

func _on_robot_registered(name: String, _record: Dictionary) -> void:
	_status.text = "Registered: " + name
	_mark_scenario("robot_registered", true)


func _on_job_published(job_id: String, _job: Dictionary) -> void:
	_status.text = "Job published: " + job_id


func _on_work_settled(robot: String, fee: int) -> void:
	_status.text = "Settled %s: %d REV" % [robot, fee]
	_mark_scenario("work_settled", true)


func _on_channel_message(channel: String, data: Dictionary) -> void:
	_registry_output.text += "[%s] %s\n" % [channel, JSON.stringify(data)]


func _mark_scenario(key: String, value) -> void:
	var svc = get_node_or_null("/root/ScenarioService")
	if svc:
		svc.context[key] = value
		svc.reevaluate()
