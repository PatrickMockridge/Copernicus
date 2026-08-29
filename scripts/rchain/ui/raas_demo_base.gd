class_name RaasDemoBase
extends Control
## Shared robotics-as-a-service demo: a customer funds a job on-chain, a robot
## executes it, and the fee scales with the work done (fee = work × rate).
## Subclasses provide the robot, actuator, command and copy via the hooks below.

signal closed()

var _coordination: CoordinationCore
var _actuator = null  # RobotActuator | KukaArmActuator (duck-typed actuate())
var _bridge: RaasBridge
var _viewport_container: SubViewportContainer
var _status: Label
var _step_labels: Array[Label] = []
var _job_counter: int = 0


# ---- Overridable hooks ----

func _heading() -> String:
	return "Robotics-as-a-Service Demo"


func _walkthrough_intro() -> String:
	return ""


func _walkthrough_steps() -> Array[String]:
	return []


func _build_viewport() -> SubViewportContainer:
	return null


func _make_actuator():
	return null


func _fund_command() -> Dictionary:
	return {}


func _idle_status() -> String:
	return "Idle. Fund a job to begin."


func _fund_status(job_id: String) -> String:
	return "Funded %s." % job_id


func _executing_status(job_id: String) -> String:
	return "Executing %s…" % job_id


func _settled_status(fee: int) -> String:
	return "Done. Fee settled: %d REV." % fee


func _add_extra_buttons(_row: HBoxContainer) -> void:
	pass


# ---- Lifecycle ----

func _ready() -> void:
	_coordination = MockCoordination.new()
	_viewport_container = _build_viewport()
	_actuator = _make_actuator()
	add_child(_actuator)

	_bridge = RaasBridge.new()
	add_child(_bridge)
	_bridge.setup(_coordination, _actuator)
	_bridge.fee_settled.connect(_on_fee_settled)

	_setup_ui()
	_set_step(1)


# ---- UI ----

func _setup_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_theme_constant_override("separation", 8)
	v.add_child(CopernicusTheme.make_heading(_heading()))

	v.add_child(_build_walkthrough())

	if _viewport_container:
		v.add_child(_viewport_container)

	var row := HBoxContainer.new()
	v.add_child(row)
	var fund_btn := Button.new()
	fund_btn.text = "Fund job"
	fund_btn.pressed.connect(_on_fund)
	row.add_child(fund_btn)
	var exec_btn := Button.new()
	exec_btn.text = "Execute job"
	exec_btn.pressed.connect(_on_execute)
	row.add_child(exec_btn)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_on_back)
	row.add_child(back_btn)
	_add_extra_buttons(row)

	_status = CopernicusTheme.make_body(_idle_status())
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)


func _build_walkthrough() -> Control:
	var card := PanelContainer.new()
	CopernicusTheme.style_card(card)

	var wv := VBoxContainer.new()
	card.add_child(wv)
	wv.add_theme_constant_override("separation", 4)
	wv.add_child(CopernicusTheme.make_heading("Walkthrough"))

	var intro := _walkthrough_intro()
	if not intro.is_empty():
		wv.add_child(CopernicusTheme.make_body(intro))

	var steps := _walkthrough_steps()
	for i in range(steps.size()):
		var label := Label.new()
		label.text = "%d. %s" % [i + 1, steps[i]]
		label.add_theme_font_size_override("font_size", CopernicusTheme.FONT_SIZE_BODY)
		label.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wv.add_child(label)
		_step_labels.append(label)

	return card


func _set_step(active: int) -> void:
	for i in range(_step_labels.size()):
		var is_active: bool = i + 1 == active
		_step_labels[i].add_theme_color_override(
			"font_color",
			CopernicusTheme.ACCENT if is_active else CopernicusTheme.TEXT_SECONDARY
		)


func _make_viewport(
	robot: Node3D,
	cam_from: Vector3,
	cam_look: Vector3,
	ground_size: Vector2,
	vp_size: Vector2i
) -> SubViewportContainer:
	var viewport := SubViewport.new()
	viewport.size = vp_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var cam := Camera3D.new()
	cam.look_at_from_position(cam_from, cam_look)
	viewport.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	viewport.add_child(light)

	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = ground_size
	viewport.add_child(ground)

	viewport.add_child(robot)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(vp_size)
	vpc.add_child(viewport)
	return vpc


# ---- Handlers ----

func _on_fund() -> void:
	_job_counter += 1
	var job_id := "demo_job_%d" % _job_counter
	var command := _fund_command()
	var r: Result = _coordination.publish_work(job_id, command)
	_status.text = _fund_status(job_id)
	_status.text += (" (error: %s)" % r.get_error()) if r.is_err() else ""
	_set_step(2)


func _on_execute() -> void:
	var job_id := "demo_job_%d" % _job_counter
	var r: Result = _bridge.execute_job(job_id, _coordination.get_my_address())
	if r.is_err():
		_status.text = "Execute error: " + r.get_error()
	else:
		_status.text = _executing_status(job_id)
		_set_step(3)


func _on_fee_settled(_robot: String, fee: int) -> void:
	_status.text = _settled_status(fee)
	_set_step(3)


func _on_back() -> void:
	closed.emit()
	queue_free()
