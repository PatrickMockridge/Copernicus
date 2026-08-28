class_name CoordinationCore
extends CopernicusModule
## Abstract coordination interface — the "beyond marketplace" layer.
## Backends: RChainCoordination (real) and MockCoordination (offline).

signal robot_registered(name: String, record: Dictionary)
signal capability_granted(robot: String, holder: String)
signal capability_revoked(robot: String)
signal ownership_transferred(robot: String, from: String, to: String)
signal job_published(job_id: String, job: Dictionary)
signal job_claimed(job_id: String, robot: String)
signal job_completed(job_id: String, result: Dictionary)
signal channel_message(channel: String, data: Dictionary)
signal work_published(job_id: String, command: Dictionary)
signal work_settled(robot: String, fee: int)
signal error_occurred(message: String)


func initialize(_config: Dictionary) -> bool:
	return true


func get_my_address() -> String:
	return ""


func is_coordination_connected() -> bool:
	return false


# --- registry ---

func register_robot(_robot: Dictionary) -> Result:
	return Result.err("CoordinationCore.register_robot not implemented")


func get_robot(_name: String) -> Result:
	return Result.err("CoordinationCore.get_robot not implemented")


func list_robots(_filter: Dictionary = {}) -> Result:
	return Result.err("CoordinationCore.list_robots not implemented")


# --- capabilities / ownership ---

func issue_capability(_robot: String) -> Result:
	return Result.err("CoordinationCore.issue_capability not implemented")


func revoke_capability(_robot: String) -> Result:
	return Result.err("CoordinationCore.revoke_capability not implemented")


func transfer_capability(_robot: String, _to: String) -> Result:
	return Result.err("CoordinationCore.transfer_capability not implemented")


func get_holder(_robot: String) -> Result:
	return Result.err("CoordinationCore.get_holder not implemented")


# --- jobs ---

func publish_job(_job: Dictionary) -> Result:
	return Result.err("CoordinationCore.publish_job not implemented")


func claim_job(_job_id: String, _robot: String) -> Result:
	return Result.err("CoordinationCore.claim_job not implemented")


func complete_job(_job_id: String, _result: Dictionary) -> Result:
	return Result.err("CoordinationCore.complete_job not implemented")


# --- channels / signals ---

func open_channel(_name: String) -> Result:
	return Result.err("CoordinationCore.open_channel not implemented")


func subscribe_channel(_name: String) -> Result:
	return Result.err("CoordinationCore.subscribe_channel not implemented")


func emit_event(_channel: String, _data: Dictionary) -> Result:
	return Result.err("CoordinationCore.emit_event not implemented")


# --- robotics-as-a-service (actuation + work-metered fee) ---

func publish_work(_job_id: String, _command: Dictionary) -> Result:
	return Result.err("CoordinationCore.publish_work not implemented")


func get_work(_job_id: String) -> Result:
	return Result.err("CoordinationCore.get_work not implemented")


func settle_work(_robot: String, _fee: int) -> Result:
	return Result.err("CoordinationCore.settle_work not implemented")


static func get_module_category() -> String:
	return "coordination"
