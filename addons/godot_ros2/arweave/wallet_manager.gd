# wallet_manager.gd
# Manages Arweave wallet files for ARIADNE blockchain operations

class_name WalletManager

## Loaded wallet address
var _address: String = ""

## Loaded wallet JWK data (for reference, not stored as native type)
var _wallet_data: Dictionary = {}

## Path to current wallet file
var _wallet_path: String = ""

## Common wallet paths to check
const _COMMON_WALLET_PATHS = [
	"res://wallet.json",
	"user://.arweave/wallet.json",
	"user://.arconnect/wallet.json",
	"~/.arweave/wallet.json"
]


## Load and validate a JWK wallet file
func load_wallet(path: String) -> bool:
	_wallet_path = path
	_wallet_data = {}

	var full_path = _expand_path(path)

	if not FileAccess.file_exists(full_path):
		push_error("Wallet file not found: " + full_path)
		return false

	var file = FileAccess.open(full_path, FileAccess.READ)
	if not file:
		push_error("Failed to open wallet file: " + full_path)
		return false

	var json_str = file.get_as_text()
	file.close()

	var jwk = JSON.parse_string(json_str)
	if jwk == null:
		push_error("Failed to parse wallet JSON: " + json_str)
		return false

	if not jwk is Dictionary:
		push_error("Invalid wallet JSON format")
		return false

	# Validate required JWK fields
	if not jwk.has("kty") or not jwk.has("n") or not jwk.has("e"):
		push_error("Invalid JWK format: missing kty, n, or e")
		return false

	_wallet_data = jwk
	_address = ""  # Address derivation requires crypto, we skip it here
	return true


## Get the wallet address (if loaded)
func get_address() -> String:
	return _address


## Get the loaded wallet path
func get_wallet_path() -> String:
	return _wallet_path


## Check if a wallet is currently loaded
func has_wallet() -> bool:
	return not _wallet_path.is_empty() and _wallet_data.size() > 0


## Find and load the first available wallet from common paths
func find_and_load_wallet() -> bool:
	for wallet_path in _COMMON_WALLET_PATHS:
		var expanded = _expand_path(wallet_path)
		if FileAccess.file_exists(expanded):
			return load_wallet(expanded)
	return false


## Set the wallet path without loading (for use with CLI --wallet flag)
func set_wallet_path(path: String) -> void:
	_wallet_path = path
	_wallet_data = {}


## Clear the loaded wallet
func clear_wallet() -> void:
	_wallet_path = ""
	_address = ""
	_wallet_data = {}


func _expand_path(path: String) -> String:
	# Expand ~ to user home directory
	if path.begins_with("~/"):
		var home = OS.get_environment("HOME")
		if home.is_empty():
			home = OS.get_environment("USERPROFILE")
		if not home.is_empty():
			path = home + "/" + path.substr(2)
	# Convert res:// and user:// paths
	elif path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	elif path.begins_with("user://"):
		path = ProjectSettings.globalize_path(path)
	return path
