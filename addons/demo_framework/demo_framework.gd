# demo_framework.gd
# EditorPlugin entry point for Demo Framework addon
# Provides shared demo infrastructure: camera, lighting, ground, robots

@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("DemoEnvironment", "Node3D", preload("res://addons/demo_framework/demo_environment.gd"), preload("res://addons/demo_framework/demo_environment.svg"))
	add_custom_type("DemoRobot", "CharacterBody3D", preload("res://addons/demo_framework/demo_robot.gd"), preload("res://addons/demo_framework/demo_robot.svg"))
	print("Demo Framework plugin loaded")


func _exit_tree() -> void:
	remove_custom_type("DemoEnvironment")
	remove_custom_type("DemoRobot")
	print("Demo Framework plugin unloaded")
