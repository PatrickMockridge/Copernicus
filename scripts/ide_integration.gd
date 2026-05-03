# ide_integration.gd
# Integration helpers for Copernicus IDE
# Provides blockchain publishing integration

class_name IDEIntegration
extends Node

const PublishPanel = preload("res://scripts/publish_panel.gd")
const RobotPublisher = preload("res://scripts/robot_publisher.gd")

## Add blockchain publish button to a toolbar
## Returns the created button
static func add_publish_button(toolbar: HBoxContainer) -> Button:
	var btn = Button.new()
	btn.text = "Publish"
	btn.tooltip_text = "Publish robot to blockchain"

	# Try to set an icon if available
	var icon = _get_blockchain_icon()
	if icon:
		btn.icon = icon

	btn.pressed.connect(_on_publish_button_pressed.bind(toolbar))

	toolbar.add_child(btn)

	return btn


## Show the publish panel
static func show_publish_panel(robot_name: String = "") -> void:
	var panel = PublishPanel.new()
	panel._name_edit.text = robot_name if not robot_name.is_empty() else _detect_robot_name()
	panel._populate_file_list()

	var viewport = Engine.get_main_loop().root
	viewport.add_child(panel)


## Get the currently selected robot name from scene
static func _detect_robot_name() -> String:
	var scene = Engine.get_main_loop().root.get_child(-1)
	if scene and scene.has_method("get_robot_root"):
		var robot_root = scene.get_robot_root()
		if robot_root:
			return robot_root.name
	return "MyRobot"


## Create a blockchain icon (simple crypto-themed)
static func _get_blockchain_icon() -> Texture2D:
	# For now, return null (no icon)
	# In production, you'd load an actual icon
	return null


static func _on_publish_button_pressed(toolbar: HBoxContainer) -> void:
	show_publish_panel()


## Quick publish with minimal config
static func quick_publish(files: Array, name: String, description: String = "", price: float = 0.0) -> Result:
	var publisher = RobotPublisher.new()

	var config = {
		"name": name,
		"description": description,
		"price": price,
		"files": files
	}

	var result = publisher.publish(config)
	return result


## Discover all robot-related files in the project
static func discover_robot_files() -> Array:
	var files: Array = []

	var search_paths = [
		"res://scripts/",
		"res://scenes/",
		"res://meshes/",
		"res://urdf/"
	]

	var extensions = ["gd", "tscn", "tres", "urdf", "glb", "gltf", "obj", "stl", "vrm"]

	for search_path in search_paths:
		files.append_array(FileUtils.scan_directory(search_path, extensions))

	return files
