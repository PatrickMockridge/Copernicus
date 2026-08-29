# scenario_service.gd
# Autoload — the Workbench Loop's progression: the scenario ladder, the live
# context (populated by the shell), and the current verdict.

extends Node

signal verdict_changed(verdict)

var model: ProgressionModel
var context: Dictionary = {}   # live state, populated by the shell (robot_loaded, joints, sensors, ...)
var active: Scenario
var verdict: ValidationResult


func _ready() -> void:
	model = ProgressionModel.new()
	_build_ladder()
	var first := model.next_unlocked()
	if not first.is_empty():
		activate(first)


func activate(id: String) -> void:
	model.activate(id)
	active = model.current()
	reevaluate()


func reevaluate() -> void:
	if active == null:
		return
	verdict = ScenarioEvaluator.evaluate(active, context)
	verdict_changed.emit(verdict)


func complete_current() -> void:
	if active == null:
		return
	model.complete(active.id)
	# "ship" (the meta scenario) passes once every prior scenario is complete.
	if _all_prior_complete():
		context["all_stages_complete"] = true
	var next := model.next_unlocked()
	if not next.is_empty():
		activate(next)
	elif _all_prior_complete():
		reevaluate()


## True when every scenario except the meta "ship" scenario is complete.
func _all_prior_complete() -> bool:
	for id in model.get_order():
		if id == "ship":
			continue
		if not model.is_completed(id):
			return false
	return true


func _build_ladder() -> void:
	model.register(_s("first_light", "First Light", "Load a sample robot and read it.", "design", [], [
		_ctx_check("robot_loaded", "Robot loaded"),
	]))
	model.register(_s("set_the_pose", "Set the Pose", "Move every joint of the sample arm and return it to zero.", "design", ["first_light"], [
		_ctx_check("all_joints_zeroed", "All joints zeroed"),
	]))
	model.register(_s("reach_the_target", "Reach the Target", "Configure Arm6 so its end-effector reaches the target marker.", "design", ["set_the_pose"], [
		_ctx_check("end_effector_reached", "End-effector on target"),
	]))
	model.register(_s("see_what_it_sees", "See What It Sees", "Turn on every sensor and confirm it produces output.", "test", ["reach_the_target"], [
		_ctx_check("lidar_active", "LIDAR live"),
		_ctx_check("camera_active", "Camera live"),
		_ctx_check("imu_active", "IMU live"),
	]))
	model.register(_s("make_it_move", "Make It Move", "Drive the differential-drive base with WASD.", "test", ["see_what_it_sees"], [
		_ctx_check("robot_moved", "Robot moved"),
	]))
	model.register(_s("wire_it_to_ros2", "Wire It to ROS2", "Connect the bridge and confirm a data stream.", "test", ["make_it_move"], [
		_ctx_check("ros2_connected", "ROS2 connected"),
	]))
	model.register(_s("register_it", "Register It", "Register this robot on-chain.", "publish", ["wire_it_to_ros2"], [
		_ctx_check("robot_registered", "Robot registered"),
	]))
	model.register(_s("put_it_on_the_market", "Put It On the Market", "List a validated design with a name, description, and price.", "publish", ["register_it"], [
		_ctx_check("listing_created", "Listing created"),
	]))
	model.register(_s("run_it_for_hire", "Run It For Hire", "Fund a job, claim it, execute, and settle a work-metered fee.", "operate", ["put_it_on_the_market"], [
		_ctx_check("work_settled", "Work settled"),
	]))
	model.register(_s("ship", "Ship a Validated Design", "Take an imported robot through the whole loop to a published design.", "design", ["run_it_for_hire"], [
		_ctx_check("all_stages_complete", "All stages complete"),
	]))


func _s(p_id: String, p_title: String, p_brief: String, p_mode: String, p_requires: Array, p_checks: Array) -> Scenario:
	var s := Scenario.make(p_id, p_title, p_brief, p_mode)
	s.requires = p_requires
	s.checks = p_checks
	return s


func _ctx_check(key: String, label: String, expect: Variant = true) -> Dictionary:
	return {"label": label, "key": key, "check": func(ctx) -> Variant: return ctx.get(key, false), "expect": expect}


## Context keys that some code actually writes (the "producers"). A check whose
## key has no producer would show a permanent false ✗, so it is hidden by the UI.
const PRODUCED_KEYS := ["robot_loaded", "all_joints_zeroed", "end_effector_reached", "robot_moved", "ros2_connected", "lidar_active", "camera_active", "imu_active", "listing_created", "robot_registered", "work_settled", "all_stages_complete"]


func is_produced(key: String) -> bool:
	return PRODUCED_KEYS.has(key)
