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


## Build a send: @"channel"!(payload).
func build_send(channel: String, payload: String) -> String:
	return '@"%s"!(%s)' % [channel, payload]


## ===== registry.rho =====

func build_register_robot(name: String, record: Dictionary) -> String:
	return '@"copernicus:registry"!("register", "%s", "%s")' % [name, JSON.stringify(record)]


func build_query(name: String) -> String:
	return 'new return in { @"copernicus:registry"!("query", "%s", *return) }' % name


func build_list_robots() -> String:
	return 'new return in { @"copernicus:registry"!("list", *return) }'


## ===== ownership.rho (capabilities + ledger) =====

func build_issue_capability(robot: String, holder: String) -> String:
	return '@"copernicus:ownership"!("issue", "%s", "%s")' % [robot, holder]


func build_transfer_capability(robot: String, to: String) -> String:
	return '@"copernicus:ownership"!("transfer", "%s", "%s")' % [robot, to]


func build_get_holder(robot: String) -> String:
	return 'new return in { @"copernicus:ownership"!("holder", "%s", *return) }' % robot


func build_revoke_capability(robot: String) -> String:
	return '@"copernicus:ownership"!("revoke", "%s")' % robot


## ===== jobs.rho =====

func build_publish_job(job_id: String, spec: Dictionary) -> String:
	return '@"copernicus:jobs"!("publish", "%s", "%s")' % [job_id, JSON.stringify(spec)]


func build_claim_job(job_id: String, robot: String) -> String:
	return '@"copernicus:jobs"!("claim", "%s", "%s")' % [job_id, robot]


func build_complete_job(job_id: String, result: Dictionary) -> String:
	return '@"copernicus:jobs"!("complete", "%s", "%s")' % [job_id, JSON.stringify(result)]


## ===== channels.rho (pub/sub) =====

func build_open_channel(name: String) -> String:
	return '@"copernicus:channels"!("open", "%s")' % name


func build_emit(channel: String, data: Dictionary) -> String:
	return '@"copernicus:channels"!("send", "%s", "%s")' % [channel, JSON.stringify(data)]


## ===== Native revVault templates (from ~/RWallet/r-wallet/src/utils/rho.ts) =====

func build_check_balance(address: String) -> String:
	return 'new return, revVault(`rho:rchain:revVault`), balanceCh in {\n  revVault!("getBalance", "%s", *balanceCh) |\n  for (@balance <- balanceCh) { return!(balance) }\n}' % address


func build_transfer_rev(to: String, amount: int) -> String:
	return 'new revVault(`rho:rchain:revVault`), deployerId(`rho:rchain:deployerId`), deployId(`rho:rchain:deployId`), resultCh in {\n  revVault!("transfer", *deployerId, "%s", %d, *resultCh) |\n  for (_ <- resultCh) { deployId!((true, "Transfer successful (not yet finalized).")) }\n}' % [to, amount]
