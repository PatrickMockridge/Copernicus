class_name RaasBridge
extends Node
## Ties a CoordinationCore backend to an actuator: reads a funded job,
## actuates the robot, and settles the work-metered fee.

signal actuation_request(job_id: String, command: Dictionary)
signal fee_settled(robot: String, fee: int)

var _coordination: CoordinationCore = null
var _actuator = null  # RobotActuator or KukaArmActuator (duck-typed actuate())


func setup(coordination: CoordinationCore, actuator) -> void:
	_coordination = coordination
	_actuator = actuator


## Execute a funded job end-to-end: read command, actuate, settle fee = work * rate.
func execute_job(job_id: String, robot_address: String) -> Result:
	var cmd: Result = _coordination.get_work(job_id)
	if cmd.is_err():
		return cmd
	var command: Dictionary = cmd.get_data()
	actuation_request.emit(job_id, command)
	var work: float = _actuator.actuate(command)
	var rate: int = int(command.get("rate", 0))
	var fee: int = int(work * rate)
	var r := _coordination.settle_work(robot_address, fee)
	if r.is_ok():
		fee_settled.emit(robot_address, fee)
	return r
