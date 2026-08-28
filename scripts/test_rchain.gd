extends SceneTree
## Headless end-to-end test for the RChain coordination layer.
## Run: godot --headless --script res://scripts/test_rchain.gd
## The crypto checks are offline; the node e2e is skipped if no RNode is reachable.

const PRIV := "a68a6e6cca30f81bd24a719f3145d20e8424bd7b396309b0708a16c7d8000b76"
const ADDR := "11112VYAt8rUGNRRZX3eJdgagaAhtWTK8Js7F7X5iqddMVqyDTtYau"

var _failures := 0


func _init() -> void:
	_test_crypto()
	_test_sdk_terms()
	_test_node_e2e()
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


func _test_crypto() -> void:
	print("== crypto ==")
	var kp: Result = RChainCrypto.generate_keypair()
	_check(kp.is_ok() and not str(kp.get_data().get("private_key", "")).is_empty(), "generate_keypair")

	var pk: Result = RChainCrypto.public_key_from_private(PRIV)
	_check(pk.is_ok(), "public_key_from_private")

	var addr: Result = RChainCrypto.derive_rev_address(pk.get_data())
	_check(addr.is_ok() and addr.get_data() == ADDR, "derive_rev_address matches RWallet vector")

	_check(RChainCrypto.is_valid_rev_address(ADDR), "is_valid_rev_address (valid)")
	_check(not RChainCrypto.is_valid_rev_address("garbage"), "is_valid_rev_address (invalid)")

	var sig: Result = RChainCrypto.sign_deploy("Nil", 1, 1, 1000000, 0, "root", PRIV)
	_check(sig.is_ok(), "sign_deploy")
	var sd: Dictionary = sig.get_data()
	_check(RChainCrypto.verify_deploy("Nil", 1, 1, 1000000, 0, "root", sd.get("deployer", ""), sd.get("signature", "")), "verify_deploy")


func _test_sdk_terms() -> void:
	print("== sdk terms ==")
	var sdk := RholangSDK.new()
	_check(sdk.build_register_robot("TestBot", {"name": "TestBot"}).contains("copernicus:registry"), "build_register_robot")
	_check(sdk.build_query("TestBot").contains("return"), "build_query")
	_check(sdk.build_check_balance(ADDR).contains("getBalance"), "build_check_balance")
	_check(sdk.build_transfer_capability("TestBot", ADDR, ADDR).contains("transfer"), "build_transfer_capability")


func _test_node_e2e() -> void:
	print("== node e2e ==")
	var node := RNodeClient.new()
	var status: Result = node.get_status()
	if status.is_err():
		print("  SKIP  node unreachable: " + status.get_error())
		return

	var sdk := RholangSDK.new()
	var wallet := RChainWallet.new()
	wallet.set_node(node)
	wallet.set_sdk(sdk)
	_check(wallet.from_private_key(PRIV).is_ok(), "wallet from_private_key")
	_check(wallet.get_rev_address() == ADDR, "wallet rev address")

	_check(node.faucet(ADDR).is_ok(), "faucet")

	var rho := _read_file("res://addons/rchain/rho/registry.rho")
	if rho.is_empty():
		print("  SKIP  could not read registry.rho")
		return
	var signed: Result = wallet.sign_deploy(rho, status.get_data())
	_check(signed.is_ok(), "sign registry.rho")
	var dep: Result = node.deploy(signed.get_data())
	_check(dep.is_ok(), "deploy registry.rho")

	var reg_term := sdk.build_register_robot("TestBot", {"name": "TestBot", "asset_tx_id": "tx", "metadata": {}, "creator": ADDR})
	var reg_signed: Result = wallet.sign_deploy(reg_term, status.get_data())
	_check(reg_signed.is_ok(), "sign register TestBot")
	_check(node.deploy(reg_signed.get_data()).is_ok(), "deploy register TestBot")

	var q: Result = node.explore_deploy(sdk.build_query("TestBot"))
	_check(q.is_ok(), "query TestBot")


func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()
