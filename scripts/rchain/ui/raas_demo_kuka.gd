class_name RaasDemoKuka
extends RaasDemoBase
## Kuka KR210 6-DOF arm pick-and-place RaaS demo: fee = joint travel (degrees) × rate.

var _arm: KukaKR210


func _heading() -> String:
	return "Kuka KR210 Pick-and-Place (RaaS)"


func _walkthrough_intro() -> String:
	return "A customer funds a pick-and-place job on-chain; the 6-DOF arm executes it and the fee scales with total joint travel."


func _walkthrough_steps() -> Array[String]:
	return [
		"Fund a job — publish a funded pick-and-place command.",
		"Execute — the arm reads the command and runs the pick-and-place sequence.",
		"Settle — the fee (joint travel × rate) is transferred to the robot.",
	]


func _build_viewport() -> SubViewportContainer:
	_arm = KukaKR210.new()
	return _make_viewport(_arm, Vector3(2.4, 2.4, 3.6), Vector3(0, 0.7, 0), Vector2(12, 12), Vector2i(760, 440))


func _make_actuator():
	var actuator := KukaArmActuator.new()
	actuator.setup(_arm)
	return actuator


func _fund_command() -> Dictionary:
	return {"action": "pick_and_place", "rate": 5}


func _idle_status() -> String:
	return "Arm idle. Fund a job to begin."


func _fund_status(job_id: String) -> String:
	return "Funded %s: pick-and-place @ 5 REV/deg" % job_id


func _settled_status(fee: int) -> String:
	return "Pick-and-place done. Fee settled: %d REV (joint travel × rate)." % fee
