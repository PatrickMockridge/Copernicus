# ariadne_vcs.gd
# Version control via ariadne-cli (decentralized git hosting on Arweave).
# Commits use the local git CLI; push/pull/clone go through ariadne-cli.

class_name AriadneVcs
extends VcsBackend

var _ariadne: AriadneInterface


func _init() -> void:
	_ariadne = AriadneInterface.new()


static func get_module_name() -> String:
	return "Ariadne (Arweave)"


static func get_module_description() -> String:
	return "Decentralized git hosting on Arweave via ariadne-cli."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "ariadne-cli + node on PATH."


static func _static_init():
	ModuleRegistry.register("vcs", "AriadneVcs", preload("res://scripts/vcs/ariadne_vcs.gd"))


func initialize(config: Dictionary) -> bool:
	var wallet := str(config.get("wallet", ""))
	var create := bool(config.get("create", false))
	var private_repo := bool(config.get("private", false))
	var r := _ariadne.initialize(wallet, create, private_repo)
	return r["exit_code"] == 0


func is_initialized() -> bool:
	return _ariadne.is_initialized()


func set_remote(url: String) -> Result:
	# Ariadne addresses repos by id rather than a git remote URL.
	return Result.ok({"repo_id": url})


func commit(message: String) -> Result:
	git_exec(["add", "-A"])
	var r := git_exec(["commit", "-m", message])
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"output": r["output"]})


func push() -> Result:
	var r := _ariadne.push()
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"output": r["output"]})


func pull() -> Result:
	var r := _ariadne.pull()
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"output": r["output"]})


func clone(url: String) -> Result:
	var r := _ariadne.clone(url)
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"output": r["output"]})


func get_status() -> Result:
	return Result.ok(_ariadne.get_status())


func get_log(limit: int = 10) -> Result:
	return Result.ok(_ariadne.get_log(limit))
