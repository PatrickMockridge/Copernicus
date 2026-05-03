# test_blockchain.gd
# Test script for blockchain flow (ARIADNE + AO Hyperobject)

extends Node3D

const ArweaveWallet = preload("res://addons/godot_ros2/arweave/arweave_wallet.gd")
const AriadneInterface = preload("res://addons/godot_ros2/arweave/ariadne_interface.gd")
const AOSDK = preload("res://addons/hyperobject/sdk/ao.gd")
const RobotHyperobject = preload("res://scripts/robot_hyperobject.gd")
const TradeManager = preload("res://addons/godot_ros2/arweave/trade_manager.gd")
const Result = preload("res://addons/primitives/result.gd")

var _wallet: ArweaveWallet
var _ariadne: AriadneInterface
var _ao: AOSDK
var _trade_manager: TradeManager

func _ready() -> void:
	print("=== Blockchain Test Starting ===")

	# Initialize ARIADNE
	_ariadne = AriadneInterface.new()

	# Initialize AO SDK
	_ao = AOSDK.new()

	# Initialize Trade Manager
	_trade_manager = TradeManager.new(_ao, _ariadne)

	print("Services initialized")

	# Try to find wallet
	_test_wallet()

func _test_wallet() -> void:
	print("\n--- Testing Wallet ---")

	# Create wallet instance
	_wallet = ArweaveWallet.new()

	# Check common wallet paths
	var wallet_paths = [
		"res://wallet.json",
		"user://wallet.json",
		"~/.arweave/wallet.json"
	]

	var found = false
	for path in wallet_paths:
		if _wallet_exists(path):
			print("Found wallet at: " + path)
			var result = _wallet.load_from_file(path)
			if result.is_ok():
				print("Wallet loaded! Address: " + _wallet.get_address())
			else:
				print("Wallet load failed: " + result.get_error())
			found = true
			break

	if not found:
		print("No wallet found in common paths")
		print("Please add wallet.json to res:// or configure wallet path")

	_test_ariadne()

func _wallet_exists(path: String) -> bool:
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

func _test_ariadne() -> void:
	print("\n--- Testing ARIADNE ---")

	# Check if ariadne-cli is available
	var node_path = _ariadne._get_node_path()
	print("Using node: " + node_path)

	# Check ARIADNE status
	var status = _ariadne.is_initialized()
	print("ARIADNE initialized in project: " + str(status))

	if not status:
		print("ARIADNE not initialized - will need to init before publish")

	_test_ao()

func _test_ao() -> void:
	print("\n--- Testing AO SDK ---")

	# Initialize AO SDK
	var init_result = _ao.initialize("https://cu.ardrive.io/v1", "https://arweave.net")
	print("AO SDK initialized: " + str(init_result.is_ok()))

	_test_publish()

func _test_publish() -> void:
	print("\n--- Testing Publish Flow ---")

	if not _wallet or not _wallet.is_loaded():
		print("SKIP: No wallet loaded")
		_finish_test()
		return

	# Create robot hyperobject (uses AO SDK directly)
	var robot = RobotHyperobject.new("TestRobot", _ao)
	robot.set_description("Test robot for blockchain publishing")

	print("RobotHyperobject created")
	print("- Repo ID: " + robot.get_repo_id())
	print("- Owner: " + robot.get_owner())

	# Register with trade manager
	_trade_manager.register(robot)
	print("Registered with trade manager")

	# Try to publish to ARIADNE
	print("\nAttempting ARIADNE push...")
	var push_result = _ariadne.push(_wallet.get_wallet_path(), false)
	print("Push result: " + str(push_result))

	if push_result["exit_code"] == 0:
		var repo_id = _ariadne.get_repo_id()
		print("SUCCESS! repo_id: " + repo_id)
		robot.set_repo_id(repo_id)
	else:
		print("Push failed: " + push_result["output"])

	_finish_test()

func _finish_test() -> void:
	print("\n=== Blockchain Test Complete ===")
	print("Summary:")
	print("- Wallet loaded: " + str(_wallet != null and _wallet.is_loaded()))
	print("- Wallet address: " + (_wallet.get_address() if _wallet else "N/A"))
	print("- ARIADNE initialized: " + str(_ariadne.is_initialized()))
	print("- Robots registered: " + str(_trade_manager.get_count()))
