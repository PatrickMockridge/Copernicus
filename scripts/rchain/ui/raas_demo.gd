class_name RaasDemo
extends Control
## Robotics-as-a-service demo: a Kuka KR210 6-DOF arm that performs a pick-and-place
## when a chain job is funded, metering joint travel and settling a fee.
## Uses MockCoordination offline by default; swap to RChainCoordination for a live node.

var _coordination: CoordinationCore
var _actuator: KukaArmActuator
var _bridge: RaasBridge
var _arm: KukaKR210
var _viewport_container: SubViewportContainer
var _status: Label
var _job_counter: int = 0


func _ready() -> void:
	# Offline in-memory backend. For a live node use RChainCoordination.new() + initialize().
	_coordination = MockCoordination.new()

	_arm = KukaKR210.new()
	_viewport_container = _build_viewport(_arm)

	_actuator = KukaArmActuator.new()
	add_child(_actuator)
	_actuator.setup(_arm)

	_bridge = RaasBridge.new()
	add_child(_bridge)
	_bridge.setup(_coordination, _actuator)
	_bridge.fee_settled.connect(_on_fee_settled)

	_setup_ui()


func _build_viewport(arm: KukaKR210) -> SubViewportContainer:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 440)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(2.4, 2.4, 3.6), Vector3(0, 0.7, 0))
	viewport.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	viewport.add_child(light)

	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(12, 12)
	viewport.add_child(ground)

	viewport.add_child(arm)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(760, 440)
	vpc.add_child(viewport)
	return vpc


func _setup_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_theme_constant_override("separation", 8)
	v.add_child(CopernicusTheme.make_heading("Kuka KR210 Pick-and-Place (RaaS)"))

	v.add_child(_viewport_container)

	var row := HBoxContainer.new()
	v.add_child(row)
	var fund_btn := Button.new()
	fund_btn.text = "Fund pick-and-place job"
	fund_btn.pressed.connect(_on_fund)
	row.add_child(fund_btn)
	var exec_btn := Button.new()
	exec_btn.text = "Execute job"
	exec_btn.pressed.connect(_on_execute)
	row.add_child(exec_btn)

	_status = CopernicusTheme.make_body("Arm idle. Fund a job to begin.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)


func _on_fund() -> void:
	_job_counter += 1
	var job_id := "demo_job_%d" % _job_counter
	var command := {"action": "pick_and_place", "rate": 5}
	var r: Result = _coordination.publish_work(job_id, command)
	_status.text = "Funded %s: pick-and-place @ %d REV/deg" % [job_id, 5]
	_status.text += (" (error: %s)" % r.get_error()) if r.is_err() else ""


func _on_execute() -> void:
	var job_id := "demo_job_%d" % _job_counter
	var r: Result = _bridge.execute_job(job_id, _coordination.get_my_address())
	if r.is_err():
		_status.text = "Execute error: " + r.get_error()
	else:
		_status.text = "Executing %s…" % job_id


func _on_fee_settled(_robot: String, fee: int) -> void:
	_status.text = "Pick-and-place done. Fee settled: %d REV (joint travel × rate)." % fee
