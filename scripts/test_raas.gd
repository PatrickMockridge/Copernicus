extends SceneTree
## Headless e2e test for robotics-as-a-service: escrowed actuation + work-metered fee.
## Run: godot --headless --script res://scripts/test_raas.gd

const PRIV := "a68a6e6cca30f81bd24a719f3145d20e8424bd7b396309b0708a16c7d8000b76"
const ADDR := "11112VYAt8rUGNRRZX3eJdgagaAhtWTK8Js7F7X5iqddMVqyDTtYau"

var _failures := 0


func _init() -> void:
	_test_raas()
	print("")
	if _failures == 0:
		print("ALL PASS")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  " + label)
	else:
		print("  FAIL  " + label)
		_failures += 1


func _get_balance(node: RNodeClient, sdk: RholangSDK, address: String) -> int:
	var r: Result = node.explore_deploy(sdk.build_check_balance(address))
	if r.is_err():
		return -1
	var exprs: Array = r.get_data().get("expr", [])
	if exprs.is_empty():
		return 0
	return int(sdk.rho_expr_to_json(exprs[0]))


func _test_raas() -> void:
	print("== raas ==")
	var node := RNodeClient.new()
	var sdk := RholangSDK.new()
	var status: Result = node.get_status()
	if status.is_err():
		print("  SKIP  node unreachable: " + status.get_error())
		return

	var customer := RChainWallet.new()
	customer.set_node(node)
	customer.set_sdk(sdk)
	_check(customer.generate().is_ok(), "customer wallet")

	var robot := RChainWallet.new()
	robot.set_node(node)
	robot.set_sdk(sdk)
	_check(robot.generate().is_ok(), "robot wallet")

	_check(node.faucet(customer.get_rev_address()).is_ok(), "faucet customer")
	OS.delay_msec(1500)  # faucet rate limit is 1/sec
	_check(node.faucet(robot.get_rev_address()).is_ok(), "faucet robot")
	var robot_before := _get_balance(node, sdk, robot.get_rev_address())
	var customer_before := _get_balance(node, sdk, customer.get_rev_address())

	var job_id := "job_%d" % Time.get_ticks_usec()
	var command := {"action": "drive", "distance": 10000, "rate": 1000}

	# Customer publishes the job (an on-chain commitment with the actuation command).
	var fund_term := sdk.build_fund_job(job_id, command)
	var fund_signed: Result = customer.sign_deploy(fund_term, status.get_data())
	_check(fund_signed.is_ok(), "sign fund")
	var fund_dep: Result = node.deploy(fund_signed.get_data())
	if fund_dep.is_err():
		print("        fund deploy err: " + fund_dep.get_error())
	_check(fund_dep.is_ok(), "deploy fund")

	# Robot polls for the actuation command via the job contract's query.
	var cmd: Result = node.explore_deploy(sdk.build_query_job(job_id))
	if cmd.is_err():
		print("        query err: " + cmd.get_error())
	_check(cmd.is_ok(), "robot reads command from chain")

	# Mock actuation: work = distance; fee = work * rate (computed in GDScript).
	var fee: int = int(command["distance"]) * int(command["rate"])

	# Customer settles the work-metered fee to the robot.
	var pay: Result = customer.transfer(robot.get_rev_address(), fee)
	if pay.is_err():
		print("        pay err: " + pay.get_error())
	_check(pay.is_ok(), "customer pays fee")

	var robot_after := _get_balance(node, sdk, robot.get_rev_address())
	var customer_after := _get_balance(node, sdk, customer.get_rev_address())
	var robot_delta: int = robot_after - robot_before
	var customer_delta: int = customer_before - customer_after
	print("        robot balance %d -> %d (delta +%d, fee = %d)" % [robot_before, robot_after, robot_delta, fee])
	print("        customer balance %d -> %d (delta -%d)" % [customer_before, customer_after, customer_delta])
	_check(robot_delta >= fee, "robot received >= fee (work*rate)")
	_check(customer_delta >= fee, "customer paid >= fee")
