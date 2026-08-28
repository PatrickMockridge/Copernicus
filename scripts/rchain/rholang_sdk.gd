class_name RholangSDK
extends RefCounted
## Builds rholang source terms and encodes/decodes RhoExpr JSON.
## Contract names and message schemas live in docs/rchain/rholang-contracts.md.
##
## Read terms (query/list/holder/balance) use `new return in { ... }` and are run via
## RNodeClient.explore_deploy. Write terms (register/issue/transfer/...) are signed deploys.


## Encode a public name as an externally-tagged RhoExpr ({"ExprString": name}).
func name_to_rho(name: String) -> Dictionary:
	return {"ExprString": name}


## Convert an externally-tagged RhoExpr into plain JSON (recursive).
func rho_expr_to_json(expr: Variant) -> Variant:
	if typeof(expr) != TYPE_DICTIONARY:
		return expr
	if expr.has("ExprInt"):
		return int(expr["ExprInt"])
	if expr.has("ExprString"):
		return str(expr["ExprString"])
	if expr.has("ExprBool"):
		return bool(expr["ExprBool"])
	if expr.has("ExprUnforg"):
		return str(expr["ExprUnforg"])
	if expr.has("ExprUri"):
		return str(expr["ExprUri"])
	if expr.has("ExprList"):
		return _map_exprs(expr["ExprList"])
	if expr.has("ExprTuple"):
		return _map_exprs(expr["ExprTuple"])
	if expr.has("ExprSet"):
		return _map_exprs(expr["ExprSet"])
	if expr.has("ExprPar"):
		return _map_exprs(expr["ExprPar"])
	if expr.has("ExprMap"):
		var m: Dictionary = {}
		for pair in expr["ExprMap"]:
			m[str(pair[0])] = rho_expr_to_json(pair[1])
		return m
	return expr


func _map_exprs(items: Array) -> Array:
	var out: Array = []
	for item in items:
		out.append(rho_expr_to_json(item))
	return out


## Embed a plain identifier as a rholang string literal (a quoted name).
## Rholang strings have NO escape sequences, so values that may contain quotes or
## backslashes (e.g. JSON) must be hex-encoded instead (see _rho_json).
func _rho_str(s: String) -> String:
	return '"%s"' % s


## Hex-encode a JSON value so it can be embedded in a rholang string literal.
func _rho_json(d: Dictionary) -> String:
	return '"%s"' % JSON.stringify(d).to_utf8_buffer().hex_encode()


## Build a send: @"channel"!(payload).
func build_send(channel: String, payload: String) -> String:
	return '@"%s"!(%s)' % [channel, payload]


## ===== registry.rho =====

func build_register_robot(name: String, record: Dictionary) -> String:
	return '@"copernicus:registry"!("register", %s, %s)' % [_rho_str(name), _rho_json(record)]


func build_query(name: String) -> String:
	return 'new return in { @"copernicus:registry"!("query", %s, *return) }' % _rho_str(name)


func build_list_robots() -> String:
	return 'new return in { @"copernicus:registry"!("list", *return) }'


## ===== ownership.rho (capabilities + ledger) =====

func build_issue_capability(robot: String, holder: String) -> String:
	return '@"copernicus:ownership"!("issue", %s, %s)' % [_rho_str(robot), _rho_str(holder)]


func build_transfer_capability(robot: String, to: String) -> String:
	return '@"copernicus:ownership"!("transfer", %s, %s)' % [_rho_str(robot), _rho_str(to)]


func build_get_holder(robot: String) -> String:
	return 'new return in { @"copernicus:ownership"!("holder", %s, *return) }' % _rho_str(robot)


func build_revoke_capability(robot: String) -> String:
	return '@"copernicus:ownership"!("revoke", %s)' % _rho_str(robot)


## ===== jobs.rho =====

func build_publish_job(job_id: String, spec: Dictionary) -> String:
	return '@"copernicus:jobs"!("publish", %s, %s)' % [_rho_str(job_id), _rho_json(spec)]


func build_claim_job(job_id: String, robot: String) -> String:
	return '@"copernicus:jobs"!("claim", %s, %s)' % [_rho_str(job_id), _rho_str(robot)]


func build_complete_job(job_id: String, result: Dictionary) -> String:
	return '@"copernicus:jobs"!("complete", %s, %s)' % [_rho_str(job_id), _rho_json(result)]


## ===== channels.rho (pub/sub) =====

func build_open_channel(name: String) -> String:
	return '@"copernicus:channels"!("open", %s)' % _rho_str(name)


func build_emit(channel: String, data: Dictionary) -> String:
	return '@"copernicus:channels"!("send", %s, %s)' % [_rho_str(channel), _rho_json(data)]


## ===== robotics-as-a-service (actuation + work-metered fee) =====
## The customer's fund deploy publishes a per-job contract that answers `query`
## (returns the actuation command, polled via explore_deploy). The robot actuates,
## meters the work, and the fee = work * rate is settled with a customer-signed
## revVault transfer. `data_at_name` is NOT used — this node's endpoint only accepts
## unforgeable names. (True on-chain escrow is not possible with this node's
## revVault, which only spends the *current* deployer's vault.)

func raas_job_name(job_id: String) -> String:
	return "copernicus:raas:job:" + job_id


func build_fund_job(job_id: String, command: Dictionary) -> String:
	return 'contract @"%s"(@"query", ret) = {\n  ret!(%s)\n}' % [raas_job_name(job_id), _rho_json(command)]


func build_query_job(job_id: String) -> String:
	return 'new return in { @"%s"!("query", *return) }' % raas_job_name(job_id)


## ===== Native revVault templates (from ~/RWallet/r-wallet/src/utils/rho.ts) =====

func build_check_balance(address: String) -> String:
	return 'new return, revVault(`rho:rchain:revVault`), balanceCh in {\n  revVault!("getBalance", %s, *balanceCh) |\n  for (@balance <- balanceCh) { return!(balance) }\n}' % _rho_str(address)


func build_transfer_rev(to: String, amount: int) -> String:
	return 'new revVault(`rho:rchain:revVault`), deployerId(`rho:rchain:deployerId`), deployId(`rho:rchain:deployId`), resultCh in {\n  revVault!("transfer", *deployerId, %s, %d, *resultCh) |\n  for (_ <- resultCh) { deployId!((true, "Transfer successful (not yet finalized).")) }\n}' % [_rho_str(to), amount]
