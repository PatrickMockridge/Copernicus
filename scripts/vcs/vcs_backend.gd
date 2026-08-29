# vcs_backend.gd
# Abstract version-control backend. Concrete backends (Ariadne on Arweave, generic
# Git for GitHub/GitLab/any remote) implement these operations; the VCS panel talks
# to whichever backend is selected.

class_name VcsBackend
extends CopernicusModule


static func get_module_category() -> String:
	return "vcs"


func initialize(_config: Dictionary) -> bool:
	return true


func is_initialized() -> bool:
	return false


func set_remote(_url: String) -> Result:
	return Result.err("not implemented")


func commit(_message: String) -> Result:
	return Result.err("not implemented")


func push() -> Result:
	return Result.err("not implemented")


func pull() -> Result:
	return Result.err("not implemented")


func clone(_url: String) -> Result:
	return Result.err("not implemented")


func get_status() -> Result:
	return Result.err("not implemented")


func get_log(_limit: int = 10) -> Result:
	return Result.err("not implemented")


## Shared helper: run a git CLI command and return {exit_code, output}.
static func git_exec(args: Array) -> Dictionary:
	var output: Array = []
	var code := OS.execute("git", PackedStringArray(args), output, true)
	var text := ""
	for chunk in output:
		text += str(chunk)
	return {"exit_code": code, "output": text}
