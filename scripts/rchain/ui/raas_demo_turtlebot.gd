class_name RaasDemoTurtlebot
extends RaasDemoBase
## Wheeled TurtleBot drive RaaS demo: fee = distance (meters) × rate.

var _robot: TurtleBot


func _heading() -> String:
	return "TurtleBot Drive (RaaS)"


func _walkthrough_intro() -> String:
	return "A customer funds a drive job on-chain; the wheeled robot drives and the fee scales with distance."


func _walkthrough_steps() -> Array[String]:
	return [
		"Fund a job — publish a funded drive command (distance + rate).",
		"Execute — the robot reads the command and drives the requested distance.",
		"Settle — the fee (distance × rate) is transferred to the robot.",
	]


func _build_viewport() -> SubViewportContainer:
	_robot = TurtleBot.new()
	_robot.position = Vector3(-2, 0.5, 0)
	return _make_viewport(_robot, Vector3(2, 5, 8), Vector3(-2, 0.5, 0), Vector2(40, 40), Vector2i(640, 360))


func _make_actuator():
	var actuator := RobotActuator.new()
	actuator.setup(_robot, 2.0)
	return actuator


func _fund_command() -> Dictionary:
	return {"action": "drive", "distance": 6.0, "rate": 5}


func _idle_status() -> String:
	return "Robot idle. Fund a job to begin."


func _fund_status(job_id: String) -> String:
	return "Funded %s: drive 6.0 m @ 5 REV/m" % job_id


func _settled_status(fee: int) -> String:
	return "Drive done. Fee settled: %d REV (distance × rate)." % fee
