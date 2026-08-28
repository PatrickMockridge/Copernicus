class_name RaasDemo
extends Control
## Robotics-as-a-service demo: a wheeled robot that drives when a chain job is
## funded, metering the work and settling a fee. Uses MockCoordination offline by
## default; swap to RChainCoordination to run against a live node.

var _coordination: CoordinationCore
var _actuator: RobotActuator
var _bridge: RaasBridge
var _robot: Node3D
var _status: Label
var _job_counter: int = 0


func _ready() -> void:
	_coordination = CoordinationSelector.create_backend("MockCoordination", {})
	_robot = _build_robot()
	_actuator = RobotActuator.new()
	add_child(_actuator)
	_actuator.setup(_robot, 2.0)

	_bridge = RaasBridge.new()
	add_child(_bridge)
	_bridge.setup(_coordination, _actuator)
	_bridge.fee_settled.connect(_on_fee_settled)

	_setup_ui()


func _build_robot() -> Node3D:
	var root := Node3D.new()

	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 8)
	cam.rotation_degrees = Vector3(-35, 0, 0)
	viewport.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	viewport.add_child(light)

	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(40, 40)
	viewport.add_child(ground)

	var robot := Node3D.new()
	robot.name = "Robot"
	robot.position = Vector3(-10, 0.5, 0)
	viewport.add_child(robot)

	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.0, 0.5, 1.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.9)
	body.material_override = mat
	robot.add_child(body)

	# The robot node itself is what the actuator translates.
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(640, 360)
	vpc.add_child(viewport)
	root.add_child(vpc)

	return robot


func _setup_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_theme_constant_override("separation", 8)
	v.add_child(CopernicusTheme.make_heading("Robotics-as-a-Service Demo"))

	# The 3D viewport (robot root's parent holds the SubViewportContainer).
	var vpc := _robot.get_parent().get_child(1)
	v.add_child(vpc)

	var row := HBoxContainer.new()
	v.add_child(row)
	var fund_btn := Button.new()
	fund_btn.text = "Fund job (drive 6 m)"
	fund_btn.pressed.connect(_on_fund)
	row.add_child(fund_btn)
	var exec_btn := Button.new()
	exec_btn.text = "Execute job"
	exec_btn.pressed.connect(_on_execute)
	row.add_child(exec_btn)

	_status = CopernicusTheme.make_body("Robot idle. Fund a job to begin.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)


func _on_fund() -> void:
	_job_counter += 1
	var job_id := "demo_job_%d" % _job_counter
	var command := {"action": "drive", "distance": 6.0, "rate": 5}
	var r: Result = _coordination.publish_work(job_id, command)
	_status.text = "Funded %s: drive %.1f m @ %d REV/m" % [job_id, 6.0, 5]
	_status.text += (" (error: %s)" % r.get_error()) if r.is_err() else ""


func _on_execute() -> void:
	var job_id := "demo_job_%d" % _job_counter
	var r: Result = _bridge.execute_job(job_id, _coordination.get_my_address())
	if r.is_err():
		_status.text = "Execute error: " + r.get_error()
	else:
		_status.text = "Executing %s…" % job_id


func _on_fee_settled(_robot: String, fee: int) -> void:
	_status.text = "Work done. Fee settled: %d REV (work × rate)." % fee
