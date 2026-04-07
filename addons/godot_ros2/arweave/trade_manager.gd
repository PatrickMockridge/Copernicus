# trade_manager.gd
# Manages robot hyperobjects and trading operations
#
# Responsibilities:
# - Registry of RobotHyperobjects by repo_id
# - Query robots by owner
# - Query robots for sale
# - Purchase / transfer workflow
# - Escrow (future)

class_name TradeManager
extends RefCounted

var _ao: AOSDK
var _ariadne: AriadneInterface

## Registry: repo_id -> RobotHyperobject
var _robots: Dictionary = {}

## Cache of robot data from AO network
var _owner_index: Dictionary = {}  # owner -> [repo_ids]
var _for_sale_index: Array = []  # repo_ids that are for sale


func _init(
	ao: AOSDK,
	ariadne: AriadneInterface
) -> void:
	_ao = ao
	_ariadne = ariadne


## ===== Registry Operations =====

func register(robot: RobotHyperobject) -> void:
	var repo_id = robot.get_repo_id()
	if repo_id.is_empty():
		push_warning("TradeManager: Cannot register robot with empty repo_id")
		return

	_robots[repo_id] = robot

	# Update owner index
	var owner = robot.get_owner()
	if not _owner_index.has(owner):
		_owner_index[owner] = []
	_owner_index[owner].append(repo_id)

	# Update for sale index
	if robot.is_for_sale():
		_for_sale_index.append(repo_id)


func unregister(repo_id: String) -> void:
	if not _robots.has(repo_id):
		return

	var robot = _robots[repo_id]
	var owner = robot.get_owner()

	# Remove from owner index
	if _owner_index.has(owner):
		_owner_index[owner].erase(repo_id)
		if _owner_index[owner].size() == 0:
			_owner_index.erase(owner)

	# Remove from for sale index
	_for_sale_index.erase(repo_id)

	_robots.erase(repo_id)


func get_robot(repo_id: String) -> RobotHyperobject:
	return _robots.get(repo_id)


func get_all() -> Array:
	return _robots.values()


func get_count() -> int:
	return _robots.size()


## ===== Query Operations =====

## Get all robots owned by an address
func get_robots_by_owner(owner: String) -> Array:
	if _owner_index.has(owner):
		var result: Array = []
		for repo_id in _owner_index[owner]:
			if _robots.has(repo_id):
				result.append(_robots[repo_id])
		return result
	return []


## Get all robots for sale
func get_robots_for_sale() -> Array:
	var result: Array = []
	for repo_id in _for_sale_index:
		if _robots.has(repo_id):
			result.append(_robots[repo_id])
	return result


## Get robots by type
func get_robots_by_type(robot_type: RobotHyperobject.RobotType) -> Array:
	var result: Array = []
	for robot in _robots.values():
		if robot._robot_type == robot_type:
			result.append(robot)
	return result


## Search robots by name (partial match)
func search_by_name(query: String) -> Array:
	var result: Array = []
	var lower_query = query.to_lower()
	for robot in _robots.values():
		if robot.get_name().to_lower().contains(lower_query):
			result.append(robot)
	return result


## ===== Trading Operations =====

## List a robot for sale
func list_for_sale(repo_id: String, price: float) -> Result:
	if not _robots.has(repo_id):
		return Result.err("Robot not found: " + repo_id)

	var robot = _robots[repo_id]

	# Only owner can list
	var wallet = WalletService.get_instance().get_wallet()
	if wallet and robot.get_owner() != wallet.get_address():
		return Result.err("Only the owner can list this robot for sale")

	robot.list_for_sale(price)
	_for_sale_index.append(repo_id)

	return Result.ok({"repo_id": repo_id, "price": price})


## Remove a robot from sale
func unlist(repo_id: String) -> Result:
	if not _robots.has(repo_id):
		return Result.err("Robot not found: " + repo_id)

	var robot = _robots[repo_id]

	# Only owner can unlist
	var wallet = WalletService.get_instance().get_wallet()
	if wallet and robot.get_owner() != wallet.get_address():
		return Result.err("Only the owner can unlist this robot")

	robot.unlist()
	_for_sale_index.erase(repo_id)

	return Result.ok({"repo_id": repo_id})


## Transfer a robot to a new owner (direct transfer, no payment)
func transfer(repo_id: String, new_owner: String) -> Result:
	if not _robots.has(repo_id):
		return Result.err("Robot not found: " + repo_id)

	var robot = _robots[repo_id]

	# Transfer via AO process
	var result = robot.transfer(new_owner)
	if result.is_err():
		return result

	# Update local registry
	# Remove from old owner index
	var old_owner = robot.get_creator()  # Keep creator unchanged
	# Note: _owner tracks current owner, not creator

	return Result.ok({
		"repo_id": repo_id,
		"new_owner": new_owner
	})


## Purchase a robot (calls transfer after payment - future: escrow)
func purchase(repo_id: String) -> Result:
	if not _robots.has(repo_id):
		return Result.err("Robot not found: " + repo_id)

	var robot = _robots[repo_id]

	# Check if for sale
	if not robot.is_for_sale():
		return Result.err("Robot is not for sale")

	# Get buyer address from wallet service
	var wallet = WalletService.get_instance().get_wallet()
	if not wallet:
		return Result.err("No wallet loaded")

	# TODO: Payment / escrow logic
	# For now, just do direct transfer

	return transfer(repo_id, wallet.get_address())


## ===== Network Sync =====

## Refresh registry from AO network
func sync_from_network() -> Result:
	if not _ao:
		return Result.err("No AO SDK")

	# TODO: Query AO network for robots
	# This would use GraphQL or similar to fetch all robot hyperobjects

	return Result.ok({})


## Refresh a single robot from AO
func sync_robot(repo_id: String) -> Result:
	if not _ao:
		return Result.err("No AO SDK")

	# Get latest state from AO process
	var robot = _robots.get(repo_id)
	if not robot:
		return Result.err("Robot not in registry")

	var process_id = robot.get_process_id()
	if process_id.is_empty():
		return Result.err("No process ID")

	var info_result = _ao.get_process_info(process_id)
	if info_result.is_err():
		return info_result

	var info = info_result.get_data()
	# Update local state from info

	return Result.ok(info)


## ===== Serialization =====

func to_dictionary() -> Dictionary:
	var robots_data: Array = []
	for robot in _robots.values():
		robots_data.append(robot.to_dictionary())

	return {
		"robots": robots_data,
		"owner_index": _owner_index,
		"for_sale_index": _for_sale_index
	}


func from_dictionary(data: Dictionary) -> void:
	_robots.clear()
	_owner_index.clear()
	_for_sale_index.clear()

	var robots_data = data.get("robots", [])
	for robot_data in robots_data:
		var robot = RobotHyperobject.new("", _ariadne, _ao)
		robot.from_dictionary(robot_data)
		_robots[robot.get_repo_id()] = robot

	_owner_index = data.get("owner_index", {})
	_for_sale_index = data.get("for_sale_index", [])
	_for_sale_index = data.get("for_sale_index", [])
