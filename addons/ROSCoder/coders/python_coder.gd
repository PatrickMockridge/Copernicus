# python_coder.gd
# AI code generation for ROS2 Python (rclpy)

class_name PythonCoder
extends Node

signal code_generated(code: String)

const GameAIResult = preload("res://addons/GameAI/core/result.gd")

const PYTHON_SYSTEM_PROMPT = """You are an expert ROS2 Python developer specializing in rclpy.

Generate clean, production-ready Python code for robotics applications.
- Use rclpy.node.Node as base class
- Follow ROS2 best practices for publishers/subscribers
- Include proper QoS profiles
- Handle spin callbacks correctly
- Include appropriate import statements

Return code in ```python``` blocks only. No explanations outside the code blocks."""


func generate_code(prompt: String) -> GameAIResult:
	var messages = [
		{"role": "system", "content": PYTHON_SYSTEM_PROMPT},
		{"role": "user", "content": prompt}
	]
	return _call_ai(messages)


func _call_ai(messages: Array) -> GameAIResult:
	# Use GameAI via autoload - chat() method
	var ai = get_tree().root.get_node("/root/GameAI")
	if not ai:
		return GameAIResult.new(false, null, {"code": -1, "message": "GameAI autoload not found"})

	var result = ai.chat(messages, {"provider": "minimax", "max_tokens": 2048})
	if result.is_err():
		return result

	var content = _extract_code_from_response(result.ok_value())
	if content.is_empty():
		return GameAIResult.new(false, null, {"code": -2, "message": "No code found in AI response"})

	code_generated.emit(content)
	return GameAIResult.new(true, {"content": content})


func _extract_code_from_response(response: Variant) -> String:
	if response == null:
		return ""

	var text: String
	if response is Dictionary:
		text = response.get("content", "")
	elif response is String:
		text = response
	else:
		text = str(response)

	# Extract ```python blocks
	var code_blocks: Array = []
	var lines = text.split("\n")
	var in_block = false
	var block_content = ""

	for line in lines:
		if line.strip_edges().begins_with("```python"):
			in_block = true
			block_content = ""
		elif line.strip_edges().begins_with("```") and in_block:
			in_block = false
			code_blocks.append(block_content)
		elif in_block:
			block_content += line + "\n"

	if not code_blocks.is_empty():
		return code_blocks[0]

	# Fallback: return as-is if no code blocks found
	return text
