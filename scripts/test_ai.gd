# test_ai.gd
# Test script for AI functionality
# Run with: godot --headless scenes/test_ai.tscn

extends Node

const GameAIResult = preload("res://addons/GameAI/core/result.gd")

var _gameai: Node
var _rosai: Node


func _ready() -> void:
	print("=== AI Test Starting ===")
	_init_ai()
	_run_tests()


func _init_ai() -> void:
	_gameai = get_node("/root/GameAI")
	_rosai = get_node("/root/ROSAI")

	if not _gameai:
		push_error("GameAI autoload not found")
		return
	if not _rosai:
		push_error("ROSAI autoload not found")
		return

	_rosai.set_ai(_gameai)
	print("AI instances initialized")


func _run_tests() -> void:
	# Test 1: Check API key from .env
	print("\n--- Test 1: EnvService API Key ---")
	var api_key = EnvService.get_anthropic_key()
	var base_url = EnvService.get_var("ANTHROPIC_BASE_URL")
	if api_key.is_empty():
		print("FAIL: No Anthropic API key found in .env")
	else:
		print("PASS: Anthropic API key found (length=%d)" % api_key.length())
		print("Base URL: ", base_url)

	# Test 2: Configure AI with Minimax endpoint
	print("\n--- Test 2: AI Configuration ---")
	_gameai.configure({
		"anthropic": {"api_key": api_key, "base_url": base_url},
		"default": "anthropic"
	})
	var configured = _gameai.get_default_provider()
	print("Default provider: ", configured)

	# Test 3: Simple chat
	print("\n--- Test 3: Anthropic Chat ---")
	_test_anthropic_chat()

	# Test 4: Generate behavior
	print("\n--- Test 4: Generate Behavior ---")
	_test_generate_behavior()


func _test_anthropic_chat() -> void:
	var result = _gameai.chat([{"role": "user", "content": "Say 'Hello, Robot!' if you can hear me."}], {"max_tokens": 50})
	if result.is_ok():
		var data = result.ok_value()
		var content = data.get("content", "") if data and data is Dictionary else str(result.ok_value())
		print("PASS: Chat response received: ", content.substr(0, 100))
	else:
		var err = result.err_value()
		print("FAIL: Chat error: ", err)


func _test_generate_behavior() -> void:
	_rosai.behavior_generated.connect(_on_behavior_done)
	_rosai.generate_behavior("obstacle_avoid")
	print("Behavior generation started...")


func _on_behavior_done(result: GameAIResult) -> void:
	if result.is_ok():
		var content = result.ok_value()
		if content is Dictionary:
			content = content.get("content", "")
		print("PASS: Behavior generated:")
		print(content.substr(0, 500) if content else "(empty)")
	else:
		var err = result.err_value()
		print("FAIL: Behavior error: ", err)
	print("\n=== AI Test Complete ===")