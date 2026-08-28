class_name MockCoordination
extends CoordinationCore
## Offline in-memory coordination backend for testing.

var _robots: Dictionary = {}
var _holders: Dictionary = {}
var _jobs: Dictionary = {}
var _channels: Dictionary = {}
var _works: Dictionary = {}
var _my_address: String = "mock_wallet_abc123"


static func _static_init():
	ModuleRegistry.register("coordination", "MockCoordination", preload("res://scripts/coordination/mock_coordination.gd"))


static func get_module_name() -> String:
	return "Mock Coordination"


static func get_module_description() -> String:
	return "Offline in-memory coordination for testing."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "None - in-memory mock"


static func get_module_category() -> String:
	return "coordination"


func get_my_address() -> String:
	return _my_address


func is_coordination_connected() -> bool:
	return true


func register_robot(robot: Dictionary) -> Result:
	var name: String = robot.get("name", "")
	_robots[name] = robot
	robot_registered.emit(name, robot)
	return Result.ok(robot)


func get_robot(name: String) -> Result:
	if _robots.has(name):
		return Result.ok(_robots[name])
	return Result.err("robot not found")


func list_robots(_filter: Dictionary = {}) -> Result:
	return Result.ok(_robots.values())


func issue_capability(robot: String) -> Result:
	_holders[robot] = _my_address
	capability_granted.emit(robot, _my_address)
	return Result.ok(_my_address)


func revoke_capability(robot: String) -> Result:
	_holders[robot] = "revoked"
	capability_revoked.emit(robot)
	return Result.ok(true)


func transfer_capability(robot: String, to: String) -> Result:
	var from: String = _holders.get(robot, "")
	_holders[robot] = to
	ownership_transferred.emit(robot, from, to)
	return Result.ok(true)


func get_holder(robot: String) -> Result:
	return Result.ok(_holders.get(robot, null))


func publish_job(job: Dictionary) -> Result:
	var job_id: String = job.get("id", "job_%d" % _jobs.size())
	_jobs[job_id] = job
	job_published.emit(job_id, job)
	return Result.ok(job_id)


func claim_job(job_id: String, robot: String) -> Result:
	if not _jobs.has(job_id):
		return Result.err("job not found")
	job_claimed.emit(job_id, robot)
	return Result.ok(true)


func complete_job(job_id: String, result: Dictionary) -> Result:
	job_completed.emit(job_id, result)
	return Result.ok(true)


func open_channel(name: String) -> Result:
	if not _channels.has(name):
		_channels[name] = []
	return Result.ok(true)


func subscribe_channel(name: String) -> Result:
	if not _channels.has(name):
		_channels[name] = []
	return Result.ok(true)


func emit_event(channel: String, data: Dictionary) -> Result:
	if not _channels.has(channel):
		_channels[channel] = []
	_channels[channel].append(data)
	channel_message.emit(channel, data)
	return Result.ok(true)


func publish_work(job_id: String, command: Dictionary) -> Result:
	_works[job_id] = command
	work_published.emit(job_id, command)
	return Result.ok(job_id)


func get_work(job_id: String) -> Result:
	if _works.has(job_id):
		return Result.ok(_works[job_id])
	return Result.err("work not found")


func settle_work(robot: String, fee: int) -> Result:
	work_settled.emit(robot, fee)
	return Result.ok(true)
