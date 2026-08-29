# git_vcs.gd
# Version control via the local git CLI — works with GitHub, GitLab, or any git remote.

class_name GitVcs
extends VcsBackend


static func get_module_name() -> String:
	return "Git (GitHub / GitLab / any)"


static func get_module_description() -> String:
	return "Version control via the local git CLI. Push/pull to GitHub, GitLab, or any git remote."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "The `git` CLI on PATH."


static func _static_init():
	ModuleRegistry.register("vcs", "GitVcs", preload("res://scripts/vcs/git_vcs.gd"))


func initialize(config: Dictionary) -> bool:
	var r := git_exec(["init"])
	if config.has("remote") and not str(config["remote"]).is_empty():
		git_exec(["remote", "add", "origin", str(config["remote"])])
	return r["exit_code"] == 0


func is_initialized() -> bool:
	return DirAccess.dir_exists_absolute(".git")


func set_remote(url: String) -> Result:
	git_exec(["remote", "remove", "origin"])
	var r := git_exec(["remote", "add", "origin", url])
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"remote": url})


func commit(message: String) -> Result:
	git_exec(["add", "-A"])
	var r := git_exec(["commit", "-m", message])
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"output": r["output"]})


func push() -> Result:
	var r := git_exec(["push", "-u", "origin", "HEAD"])
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"output": r["output"]})


func pull() -> Result:
	var r := git_exec(["pull"])
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"output": r["output"]})


func clone(url: String) -> Result:
	var r := git_exec(["clone", url])
	if r["exit_code"] != 0:
		return Result.err(r["output"])
	return Result.ok({"output": r["output"]})


func get_status() -> Result:
	var branch: String = str(git_exec(["branch", "--show-current"])["output"]).strip_edges()
	var porcelain: String = str(git_exec(["status", "--porcelain"])["output"])
	var staged: Array = []
	var modified: Array = []
	var untracked: Array = []
	for line in porcelain.split("\n"):
		if line.length() < 3:
			continue
		var code: String = line.substr(0, 2)
		var path: String = line.substr(3).strip_edges()
		if code.begins_with("??"):
			untracked.append(path)
			continue
		if code[0] != " ":
			staged.append(path)
		if code[1] != " ":
			modified.append(path)
	return Result.ok({
		"branch": branch,
		"staged": staged,
		"modified": modified,
		"untracked": untracked,
		"is_clean": porcelain.strip_edges().is_empty(),
	})


func get_log(limit: int = 10) -> Result:
	var r := git_exec(["log", "--oneline", "-n", str(limit)])
	var out: String = str(r["output"])
	var commits: Array = []
	for line in out.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			continue
		var sp: int = stripped.find(" ")
		if sp > 0:
			commits.append({"oid": stripped.substr(0, sp), "message": stripped.substr(sp + 1)})
		else:
			commits.append({"oid": stripped, "message": ""})
	return Result.ok(commits)
