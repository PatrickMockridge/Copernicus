# ariadne_interface.gd
# GDScript wrapper for ariadne-cli (decentralized git hosting on Arweave/AO)

class_name AriadneInterface

## Path to ariadne-cli node script
var _cli_path: String = ""

## Default wallet path
var _default_wallet: String = ""

## Last command output
var _last_output: String = ""
var _last_exit_code: int = 0


func _init() -> void:
	# Find ariadne-cli relative to this addon
	var addon_dir = _get_addon_dir()
	_cli_path = addon_dir + "../../node_modules/.bin/ariadne"


func _get_addon_dir() -> String:
	# Get the directory containing this script
	var script = get_script() as Script
	if script:
		var path = script.resource_path
		if path.begins_with("res://"):
			path = path.replace("res://", "")
			var slash_pos = path.find("/")
			if slash_pos > 0:
				path = path.substr(0, slash_pos)
			return path
	return ""


func _get_node_path() -> String:
	# Find node executable
	var nvm_node = OS.get_environment("USERPROFILE") + "/.nvm/versions/node/v22.22.2/bin/node"
	if FileAccess.file_exists(nvm_node):
		return nvm_node
	# Fallback to system node
	return "node"


func _execute_command_blocking(args: Array) -> Dictionary:
	_last_output = ""
	_last_exit_code = 0

	var node_path = _get_node_path()
	var cmd_str = node_path + " " + _cli_path + " " + " ".join(args)

	var output = []
	var exit_code = OS.execute(cmd_str, [], output, true)
	_last_exit_code = exit_code

	if output.size() > 0:
		_last_output = output[0]

	return {
		"exit_code": exit_code,
		"output": _last_output
	}


## Check if ariadne is properly initialized in this repository
func is_initialized() -> bool:
	var config_path = ".gitariadne"
	return FileAccess.file_exists(config_path)


## Get the repository ID (manifest TX ID) from .gitariadne config
func get_repo_id() -> String:
	if not is_initialized():
		return ""

	var file = FileAccess.open(".gitariadne", FileAccess.READ)
	if not file:
		return ""

	var content = file.get_as_text()
	file.close()

	# Simple parsing for repoId
	var lines = content.split("\n")
	for line in lines:
		if line.begins_with("repoId"):
			var parts = line.split("=")
			if parts.size() >= 2:
				return parts[1].strip_edges()
	return ""


## Initialize ARIADNE tracking in the current git repository
func initialize(wallet_path: String = "", create: bool = false, private_repo: bool = false) -> Dictionary:
	if wallet_path.is_empty():
		wallet_path = _default_wallet

	var args = ["init"]
	if create:
		args.append("--create")
	if private_repo:
		args.append("--private")
	if not wallet_path.is_empty():
		args += ["--wallet", wallet_path]

	return _execute_command_blocking(args)


## Push commits to Arweave
func push(wallet_path: String = "", private_repo: bool = false) -> Dictionary:
	if wallet_path.is_empty():
		wallet_path = _default_wallet

	var args = ["push"]
	if private_repo:
		args.append("--private")
	if not wallet_path.is_empty():
		args += ["--wallet", wallet_path]

	return _execute_command_blocking(args)


## Pull commits from Arweave
func pull() -> Dictionary:
	return _execute_command_blocking(["pull"])


## Clone a repository from ARIADNE
func clone(repo_id: String, wallet_path: String = "") -> Dictionary:
	if wallet_path.is_empty():
		wallet_path = _default_wallet

	var args = ["clone", repo_id]
	if not wallet_path.is_empty():
		args += ["--wallet", wallet_path]

	return _execute_command_blocking(args)


## Get working tree status
## Returns Dictionary with keys: branch, staged[], modified[], untracked[], is_clean
func get_status() -> Dictionary:
	var result = _execute_command_blocking(["status"])

	var status = {
		"branch": "",
		"staged": [],
		"modified": [],
		"untracked": [],
		"is_clean": false
	}

	if result["exit_code"] != 0:
		status["error"] = result["output"]
		return status

	var lines = result["output"].split("\n")
	var current_section = ""

	for line in lines:
		line = line.strip_edges()
		if line.begins_with("On branch:"):
			status["branch"] = line.replace("On branch:", "").strip_edges()
		elif line == "Nothing to commit, working tree clean":
			status["is_clean"] = true
		elif line == "Changes to be committed:":
			current_section = "staged"
		elif line == "Changes not staged for commit:":
			current_section = "modified"
		elif line == "Untracked files:":
			current_section = "untracked"
		elif line.begins_with("  "):
			# File entry
			var file_path = line.replace("new file:   ", "").replace("modified:   ", "").strip_edges()
			if not file_path.is_empty() and current_section != "":
				status[current_section].append(file_path)

	return status


## Get commit history
## Returns Array of Dictionary with keys: oid, author, email, date, message
func get_log(limit: int = 10) -> Array:
	var result = _execute_command_blocking(["log", "--number", str(limit)])

	var commits = []

	if result["exit_code"] != 0:
		return commits

	var lines = result["output"].split("\n")
	var current_commit = null

	for line in lines:
		line = line.strip_edges()
		if line.begins_with("commit "):
			if current_commit:
				commits.append(current_commit)
			current_commit = {
				"oid": line.replace("commit ", ""),
				"author": "",
				"email": "",
				"date": "",
				"message": ""
			}
		elif line.begins_with("Author:"):
			var author_line = line.replace("Author:", "").strip_edges()
			var email_start = author_line.find("<")
			var email_end = author_line.find(">")
			if email_start >= 0 and email_end >= 0:
				current_commit["author"] = author_line.substr(0, email_start).strip_edges()
				current_commit["email"] = author_line.substr(email_start + 1, email_end - email_start - 1)
			else:
				current_commit["author"] = author_line
		elif line.begins_with("Date:"):
			current_commit["date"] = line.replace("Date:", "").strip_edges()
		elif not line.is_empty() and current_commit and current_commit["message"].is_empty():
			current_commit["message"] = line

	if current_commit:
		commits.append(current_commit)

	return commits


## Set the default wallet path
func set_default_wallet(path: String) -> void:
	_default_wallet = path


## Get the default wallet path
func get_default_wallet() -> String:
	return _default_wallet


## Get the last command output
func get_last_output() -> String:
	return _last_output


## Get the last exit code
func get_last_exit_code() -> int:
	return _last_exit_code
