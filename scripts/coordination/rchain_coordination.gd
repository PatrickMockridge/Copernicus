class_name RChainCoordination
extends CoordinationCore
## Real coordination backend: deploys rholang contracts against RChain/RNode.

var _wallet: RChainWallet
var _node: RNodeClient
var _sdk: RholangSDK
var _bridge: SignalBridge


func initialize(config: Dictionary) -> bool:
	_wallet = config.get("wallet", RChainService.wallet)
	_node = config.get("node", RChainService.node)
	_sdk = config.get("sdk", RChainService.sdk)
	_bridge = config.get("bridge", RChainService.bridge)
	return true


static func _static_init():
	ModuleRegistry.register("coordination", "RChainCoordination", preload("res://scripts/coordination/rchain_coordination.gd"))


static func get_module_name() -> String:
	return "RChain Coordination"


static func get_module_description() -> String:
	return "On-chain coordination via RChain/RNode (capabilities, jobs, channels)."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "A reachable RNode (default http://localhost:40403)."


static func get_module_category() -> String:
	return "coordination"


func get_my_address() -> String:
	return _wallet.get_rev_address() if _wallet else ""


func is_coordination_connected() -> bool:
	if _node == null:
		return false
	return _node.get_status().is_ok()


# --- registry ---

func register_robot(robot: Dictionary) -> Result:
	var name: String = robot.get("name", "")
	var r := _wallet.deploy_term(_sdk.build_register_robot(name, robot))
	if r.is_ok():
		robot_registered.emit(name, robot)
	return r


func get_robot(name: String) -> Result:
	var r := _node.explore_deploy(_sdk.build_query(name))
	if r.is_err():
		return r
	var exprs: Array = r.get_data().get("expr", [])
	if exprs.is_empty():
		return Result.ok(null)
	var parsed = _sdk.rho_expr_to_json(exprs[0])
	return Result.ok(_decode_record(parsed))


func list_robots(_filter: Dictionary = {}) -> Result:
	var r := _node.explore_deploy(_sdk.build_list_robots())
	if r.is_err():
		return r
	var exprs: Array = r.get_data().get("expr", [])
	var records: Array = []
	if not exprs.is_empty():
		var m = _sdk.rho_expr_to_json(exprs[0])
		if typeof(m) == TYPE_DICTIONARY:
			for k in m.keys():
				records.append(_decode_record(m[k]))
	return Result.ok(records)


func _decode_record(v: Variant) -> Variant:
	if typeof(v) == TYPE_STRING:
		var parsed = JSON.parse_string(str(v))
		return parsed if parsed != null else v
	return v


# --- capabilities / ownership ---

func issue_capability(robot: String) -> Result:
	var holder := get_my_address()
	var r := _wallet.deploy_term(_sdk.build_issue_capability(robot, holder))
	if r.is_ok():
		capability_granted.emit(robot, holder)
	return r


func revoke_capability(robot: String) -> Result:
	var r := _wallet.deploy_term(_sdk.build_revoke_capability(robot))
	if r.is_ok():
		capability_revoked.emit(robot)
	return r


func transfer_capability(robot: String, to: String) -> Result:
	var from := get_my_address()
	var r := _wallet.deploy_term(_sdk.build_transfer_capability(robot, to))
	if r.is_ok():
		ownership_transferred.emit(robot, from, to)
	return r


func get_holder(robot: String) -> Result:
	var r := _node.explore_deploy(_sdk.build_get_holder(robot))
	if r.is_err():
		return r
	var exprs: Array = r.get_data().get("expr", [])
	if exprs.is_empty():
		return Result.ok(null)
	return Result.ok(_sdk.rho_expr_to_json(exprs[0]))


# --- jobs ---

func publish_job(job: Dictionary) -> Result:
	var job_id: String = job.get("id", str(Time.get_unix_time_from_system()))
	var r := _wallet.deploy_term(_sdk.build_publish_job(job_id, job))
	if r.is_ok():
		job_published.emit(job_id, job)
	return r


func claim_job(job_id: String, robot: String) -> Result:
	var r := _wallet.deploy_term(_sdk.build_claim_job(job_id, robot))
	if r.is_ok():
		job_claimed.emit(job_id, robot)
	return r


func complete_job(job_id: String, result: Dictionary) -> Result:
	var r := _wallet.deploy_term(_sdk.build_complete_job(job_id, result))
	if r.is_ok():
		job_completed.emit(job_id, result)
	return r


# --- channels / signals ---

func open_channel(name: String) -> Result:
	return _wallet.deploy_term(_sdk.build_open_channel(name))


func subscribe_channel(name: String) -> Result:
	if _bridge:
		_bridge.register_channel(name)
	return _wallet.deploy_term(_sdk.build_open_channel(name))


func emit_event(channel: String, data: Dictionary) -> Result:
	if _bridge:
		return _bridge.emit(channel, data)
	return _wallet.deploy_term(_sdk.build_emit(channel, data))
