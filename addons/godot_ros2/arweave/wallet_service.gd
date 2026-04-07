# wallet_service.gd
# Global wallet service - single source of truth for wallet across ARIADNE and AO Hyperobject
# Implements singleton pattern via autoload

class_name WalletService
extends Node

## Singleton instance
static var _instance: WalletService = null

## Current wallet
var _wallet: ArweaveWallet = null

## Signal emitted when wallet changes
signal wallet_changed(wallet: ArweaveWallet)
signal wallet_cleared()


static func get_instance() -> WalletService:
	if _instance == null:
		_instance = WalletService.new()
	return _instance


func _init() -> void:
	# Make this a singleton
	if _instance == null:
		_instance = self
	else:
		push_warning("WalletService: Multiple instances created")


## Load wallet from file path
func load_wallet(path: String) -> Result:
	var wallet = ArweaveWallet.new()
	var result = wallet.load_from_file(path)

	if result.is_ok():
		_wallet = wallet
		wallet_changed.emit(_wallet)
		return result

	return result


## Load wallet from JWK dictionary
func load_wallet_from_jwk(jwk: Dictionary) -> Result:
	_wallet = ArweaveWallet.from_jwk(jwk)
	wallet_changed.emit(_wallet)
	return Result.ok({"address": _wallet.get_address()})


## Find and load wallet from common paths
func find_wallet() -> Result:
	var wallet = ArweaveWallet.new()
	var result = wallet.find_and_load()

	if result.is_ok():
		_wallet = wallet
		wallet_changed.emit(_wallet)

	return result


## Get current wallet
func get_wallet() -> ArweaveWallet:
	return _wallet


## Get current wallet address
func get_address() -> String:
	if _wallet:
		return _wallet.get_address()
	return ""


## Check if wallet is loaded
func has_wallet() -> bool:
	return _wallet != null and _wallet.is_loaded()


## Clear wallet
func clear_wallet() -> void:
	_wallet = null
	wallet_cleared.emit()


## Set wallet directly (for testing or external initialization)
func set_wallet(wallet: ArweaveWallet) -> void:
	_wallet = wallet
	wallet_changed.emit(_wallet)


## Get JWK data from current wallet
func get_jwk() -> Dictionary:
	if _wallet:
		return _wallet.get_jwk()
	return {}


## Check wallet existence without loading
func wallet_exists(path: String) -> bool:
	var full_path = _expand_path(path)
	return FileAccess.file_exists(full_path)


func _expand_path(path: String) -> String:
	if path.begins_with("~/"):
		var home = OS.get_environment("HOME")
		if home.is_empty():
			home = OS.get_environment("USERPROFILE")
		if not home.is_empty():
			path = home + "/" + path.substr(2)
	elif path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	elif path.begins_with("user://"):
		path = ProjectSettings.globalize_path(path)
	return path