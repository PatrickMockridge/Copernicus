class_name RChainWallet
extends Wallet
## RChain identity: key lifecycle, REV address, deploy signing, balance/transfer.
## Crypto primitives come from the Rust GDExtension via the RChainCrypto wrapper.

var _private_key: String = ""
var _public_key: String = ""
var _rev_address: String = ""

var _node: RNodeClient = null
var _sdk: RholangSDK = null


func _init() -> void:
	super("secp256k1")


func set_node(node: RNodeClient) -> void:
	_node = node


func set_sdk(sdk: RholangSDK) -> void:
	_sdk = sdk


func is_ready() -> bool:
	return not _private_key.is_empty()


func has_private_key() -> bool:
	return not _private_key.is_empty()


func generate() -> Result:
	var r := RChainCrypto.generate_keypair()
	if r.is_err():
		return r
	return _apply_keypair(r.get_data())


func from_private_key(priv_hex: String) -> Result:
	var pk := RChainCrypto.public_key_from_private(priv_hex)
	if pk.is_err():
		return pk
	return _apply_keypair({"private_key": priv_hex.trim_prefix("0x"), "public_key": pk.get_data()})


func _apply_keypair(d: Dictionary) -> Result:
	_private_key = str(d.get("private_key", ""))
	_public_key = str(d.get("public_key", ""))
	var addr := RChainCrypto.derive_rev_address(_public_key)
	if addr.is_err():
		return addr
	_rev_address = str(addr.get_data())
	_address = _rev_address
	set_signer(Callable(self, "_rchain_signer"))
	return Result.ok({"private_key": _private_key, "public_key": _public_key, "address": _rev_address})


func _rchain_signer(_data: PackedByteArray) -> PackedByteArray:
	# Deploy signing is done via RChainCrypto.sign_deploy; generic signer is unused.
	return PackedByteArray()


func export_private_key() -> String:
	return _private_key


func get_public_key() -> String:
	return _public_key


func get_rev_address() -> String:
	return _rev_address


## Sign a deploy, filling node-derived fields from node_status.
## node_status: result of RNodeClient.get_status().
func sign_deploy(term: String, node_status: Dictionary = {}) -> Result:
	if not is_ready():
		return Result.err("wallet has no private key")
	var timestamp: int = node_status.get("timestamp", int(Time.get_unix_time_from_system() * 1000.0))
	var phlo_price: int = node_status.get("minPhloPrice", 1)
	var phlo_limit: int = node_status.get("phloLimit", 1000000)
	var valid_after: int = node_status.get("latestBlockNumber", 0)
	var shard_id: String = node_status.get("shardId", "root")
	var sig: Result = RChainCrypto.sign_deploy(term, timestamp, phlo_price, phlo_limit, valid_after, shard_id, _private_key)
	if sig.is_err():
		return sig
	var s: Dictionary = sig.get_data()
	return Result.ok({
		"data": {
			"term": term,
			"timestamp": timestamp,
			"phloPrice": phlo_price,
			"phloLimit": phlo_limit,
			"validAfterBlockNumber": valid_after,
			"shardId": shard_id,
		},
		"deployer": s.get("deployer", ""),
		"signature": s.get("signature", ""),
		"sigAlgorithm": s.get("sig_algorithm", "secp256k1"),
	})


## Check balance via the native revVault getBalance term.
func check_balance() -> Result:
	if _node == null or _sdk == null:
		return Result.err("wallet not connected")
	var term := _sdk.build_check_balance(_rev_address)
	var r := _node.explore_deploy(term)
	if r.is_err():
		return r
	var data: Dictionary = r.get_data()
	return Result.ok(data.get("expr", []))


## Transfer REV via the native revVault transfer term (signed deploy).
func transfer(to: String, amount: int) -> Result:
	if _node == null or _sdk == null:
		return Result.err("wallet not connected")
	var term := _sdk.build_transfer_rev(to, amount)
	return deploy_term(term)


## Sign and deploy an arbitrary rholang term; returns {deploy_id, result}.
func deploy_term(term: String) -> Result:
	var status := _node.get_status()
	if status.is_err():
		return status
	var signed := sign_deploy(term, status.get_data())
	if signed.is_err():
		return signed
	return _node.deploy(signed.get_data())
