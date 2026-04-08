# python_coder.gd
# AI code generation for ROS2 Python (rclpy)

class_name PythonCoder
extends Node

signal code_generated(code: String)
signal multi_file_generated(files: Dictionary)

const GameAIResult = preload("res://addons/GameAI/core/result.gd")

const PYTHON_SYSTEM_PROMPT = """You are an expert ROS2 Python developer specializing in rclpy.

Generate clean, production-ready Python code for robotics applications.
- Use rclpy.node.Node as base class
- Follow ROS2 best practices for publishers/subscribers
- Include proper QoS profiles
- Handle spin callbacks correctly
- Include appropriate import statements

Return code in ```python``` blocks only. No explanations outside the code blocks."""

const MULTI_FILE_SYSTEM_PROMPT = """You are an expert ROS2 Python developer specializing in rclpy.

Generate a complete ROS2 package structure with multiple files. For the given robot behavior, generate ALL of the following:
1. Python node file (the main rclpy node)
2. Launch file (Python-based launch.py)
3. Configuration file (YAML with default parameters)
4. Package manifest (package.xml)

Use this format for multiple files:
```file:filename.py
<code for this file>
```
```file:launch/launch.py
<code for launch file>
```
```file:config/params.yaml
<code for config>
```
```file:package.xml
<package manifest>
```

Only output the code blocks, no explanations."""


func generate_code(prompt: String) -> GameAIResult:
	var messages = [
		{"role": "system", "content": PYTHON_SYSTEM_PROMPT},
		{"role": "user", "content": prompt}
	]
	return _call_ai(messages)


func generate_full_package(prompt: String) -> GameAIResult:
	var messages = [
		{"role": "system", "content": MULTI_FILE_SYSTEM_PROMPT},
		{"role": "user", "content": prompt}
	]
	return _call_ai_multi(messages)


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


func _call_ai_multi(messages: Array) -> GameAIResult:
	# Use GameAI via autoload - chat() method
	var ai = get_tree().root.get_node("/root/GameAI")
	if not ai:
		return GameAIResult.new(false, null, {"code": -1, "message": "GameAI autoload not found"})

	var result = ai.chat(messages, {"provider": "minimax", "max_tokens": 4096})
	if result.is_err():
		return result

	var files = _extract_multi_file_from_response(result.ok_value())
	if files.is_empty():
		return GameAIResult.new(false, null, {"code": -2, "message": "No code found in AI response"})

	multi_file_generated.emit(files)
	return GameAIResult.new(true, {"files": files})


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


func _extract_multi_file_from_response(response: Variant) -> Dictionary:
	if response == null:
		return {}

	var text: String
	if response is Dictionary:
		text = response.get("content", "")
	elif response is String:
		text = response
	else:
		text = str(response)

	var files: Dictionary = {}
	var lines = text.split("\n")
	var current_file = ""
	var current_content = ""
	var in_block = false

	for line in lines:
		var stripped = line.strip_edges()
		if stripped.begins_with("```file:"):
			# Save previous file
			if not current_file.is_empty() and not current_content.is_empty():
				files[current_file] = current_content
			# Extract filename
			var colon_idx = stripped.find(":")
			if colon_idx >= 0:
				current_file = stripped.substr(colon_idx + 1).strip_edges()
			current_content = ""
			in_block = true
		elif stripped.begins_with("```") and in_block:
			in_block = false
			if not current_file.is_empty() and not current_content.is_empty():
				files[current_file] = current_content
			current_file = ""
			current_content = ""
		elif in_block:
			current_content += line + "\n"

	# Don't forget the last file
	if not current_file.is_empty() and not current_content.is_empty():
		files[current_file] = current_content

	return files


func generate_launch_file(node_name: String, package_name: String = "robot_bringup") -> GameAIResult:
	var launch_content = """\
from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    return LaunchDescription([
        Node(
            package='%s',
            executable='%s',
            name='%s',
            output='screen',
            parameters=[]
        ),
    ])
""" % [package_name, node_name, node_name]

	return GameAIResult.new(true, {"content": launch_content})
