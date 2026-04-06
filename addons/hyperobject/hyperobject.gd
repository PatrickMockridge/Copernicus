# hyperobject.gd
# Hyperobject SDK - General Purpose AO SDK for Godot 4
# AO (Actor-Oriented) compute + Arweave persistence
# Built composably from primitives + HyperBEAM + ArDrive

extends Node

const VERSION = "1.0.0"

var _wallet: Wallet
var _ao: AOSDK
var _config: Dictionary = {}


func _init() -> void:
	_ao = AOSDK.new()


func configure(config: Dictionary) -> void:
	_config = config


func get_config() -> Dictionary:
	return _config


func initialize(
	hyperbeam_url: String = "http://localhost:10000",
	arweave_gateway: String = "https://arweave.net"
) -> Result:
	_config = {
		"hyperbeam_url": hyperbeam_url,
		"arweave_gateway": arweave_gateway
	}
	return _ao.initialize(hyperbeam_url, arweave_gateway)


func set_wallet(wallet: Wallet) -> void:
	_wallet = wallet
	_ao.set_wallet(wallet)


func get_wallet() -> Wallet:
	return _wallet


func get_address() -> String:
	if _wallet:
		return _wallet.get_address()
	return ""


func get_ao() -> AOSDK:
	return _ao


func get_version() -> String:
	return VERSION


func get_process_info(process_id: String) -> Result:
	return _ao.get_process_info(process_id)


func schedule_message(process_id: String, message: Dictionary) -> Result:
	return _ao.schedule_message(process_id, message)


func process_call(process_id: String, handler: String, args: Dictionary) -> Result:
	return _ao.process_call(process_id, handler, args)


func spawn_process(module: String, code: PackedByteArray, initial_state: Dictionary = {}) -> Result:
	return _ao.spawn_process(module, code, initial_state)


func upload_asset(path: String, tags: Dictionary = {}) -> Result:
	return _ao.upload_asset(path, tags)


func download_asset(tx_id: String, save_path: String) -> Result:
	return _ao.download_asset(tx_id, save_path)


static func generate_wallet(key_type: String = "secp256k1") -> Wallet:
	return Wallet.create(key_type)


static func load_wallet_from_file(path: String) -> Wallet:
	var f = FileAccess.get_file_as_string(path)
	if f.is_empty():
		return null
	var json = JSON.parse_string(f)
	if json:
		return Wallet.Secp256k1Wallet.from_jwk(json)
	return null
