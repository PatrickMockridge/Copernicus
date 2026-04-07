# arweave_wallet.gd
# Unified Arweave wallet for ARIADNE + AO Hyperobject operations
# Wraps JWK loading and provides wallet interface for all blockchain operations

class_name ArweaveWallet
extends Wallet

var _jwk_data: Dictionary = {}
var _wallet_path: String = ""

## Common wallet paths to check
const COMMON_WALLET_PATHS = [
	"res://wallet.json",
	"user://.arweave/wallet.json",
	"user://.arconnect/wallet.json",
	"~/.arweave/wallet.json"
]


func _init() -> void:
	super._init("rsa")


## Load wallet from JWK file
func load_from_file(path: String) -> Result:
	_wallet_path = path
	_jwk_data = {}

	var full_path = _expand_path(path)

	if not FileAccess.file_exists(full_path):
		return Result.err("Wallet file not found: " + full_path)

	var file = FileAccess.open(full_path, FileAccess.READ)
	if not file:
		return Result.err("Failed to open wallet file: " + full_path)

	var json_str = file.get_as_text()
	file.close()

	var jwk = JSON.parse_string(json_str)
	if jwk == null:
		return Result.err("Failed to parse wallet JSON")

	if not jwk is Dictionary:
		return Result.err("Invalid wallet JSON format")

	# Validate required JWK fields
	if not jwk.has("kty") or not jwk.has("n") or not jwk.has("e"):
		return Result.err("Invalid JWK format: missing kty, n, or e")

	_jwk_data = jwk
	_address = jwk.get("kid", "")

	# Set signer for this wallet
	_signer = Callable(self, "_jwk_signer")

	return Result.ok({"address": _address, "path": full_path})


## Find and load the first available wallet from common paths
func find_and_load() -> Result:
	for wallet_path in COMMON_WALLET_PATHS:
		var result = load_from_file(wallet_path)
		if result.is_ok():
			return result
	return Result.err("No wallet found in common paths")


## Get wallet as JWK dictionary (for ariadne-cli and other tools)
func get_jwk() -> Dictionary:
	return _jwk_data.duplicate()


## Get the wallet path
func get_wallet_path() -> String:
	return _wallet_path


## Check if wallet is loaded
func is_loaded() -> bool:
	return _jwk_data.size() > 0


## Get wallet address (Arweave format)
func get_address() -> String:
	return _address


func _jwk_signer(data: PackedByteArray) -> PackedByteArray:
	"""Sign data using JWK private key."""
	# RSA signing would go here - requires crypto implementation
	# For now, return empty
	return PackedByteArray()


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


## Create from JWK dictionary
static func from_jwk(jwk: Dictionary) -> ArweaveWallet:
	var wallet = ArweaveWallet.new()
	wallet._jwk_data = jwk.duplicate()
	wallet._address = jwk.get("kid", "")
	wallet._signer = Callable(wallet, "_jwk_signer")
	return wallet


## Create with address only (for read-only operations)
static func from_address(address: String) -> ArweaveWallet:
	var wallet = ArweaveWallet.new()
	wallet._address = address
	return wallet