# trade_manager.gd
# Registry for managing robot hyperobjects and their trades

class_name TradeManager

var _ao: AOSDK
var _ariadne: AriadneInterface
var _robots: Dictionary = {}  # repo_id -> RobotHyperobject


func _init(ao: AOSDK, ariadne: AriadneInterface) -> void:
	_ao = ao
	_ariadne = ariadne


## Register a robot hyperobject
func register(robot: RobotHyperobject) -> void:
	var repo_id = robot.get_repo_id()
	if not repo_id.is_empty():
		_robots[repo_id] = robot


## Unregister a robot by repo_id
func unregister(repo_id: String) -> void:
	_robots.erase(repo_id)


## Get a robot by repo_id
func get_robot(repo_id: String) -> RobotHyperobject:
	return _robots.get(repo_id)


## Get all registered robots
func get_all() -> Array:
	return _robots.values()


## Get robots by owner
func get_by_owner(owner: String) -> Array:
	var result: Array = []
	for robot in _robots.values():
		if robot.get_owner() == owner:
			result.append(robot)
	return result


## Get robots for sale
func get_for_sale() -> Array:
	var result: Array = []
	for robot in _robots.values():
		if robot.is_for_sale():
			result.append(robot)
	return result


## Get count of registered robots
func get_count() -> int:
	return _robots.size()


## Clear all registrations
func clear() -> void:
	_robots.clear()


## Load wallet and configure AO SDK
func configure_wallet(wallet: ArweaveWallet) -> Result:
	if not wallet.is_loaded():
		return Result.err("Wallet not loaded")

	_ao.set_wallet(wallet)
	return Result.ok({"address": wallet.get_address()})
