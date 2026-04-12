# industrial.gd
# ROS-Industrial plugin entry point for Copernicus
# Provides industrial robot connectivity (MOTOMAN, ABB, UR, FANUC)

@tool
extends EditorPlugin

const IndustrialBackend = preload("res://addons/industrial/core/industrial_backend.gd")
const JointTrajectoryHandler = preload("res://addons/industrial/core/joint_trajectory_handler.gd")
const RobotStatusMonitor = preload("res://addons/industrial/core/robot_status_monitor.gd")
const MockIndustrial = preload("res://addons/industrial/backends/mock_industrial.gd")
const MotomanBridge = preload("res://scripts/industrial/backends/motoman_bridge.gd")
const IndustrialSelector = preload("res://scripts/industrial/industrial_selector.gd")

var _selector_instance: IndustrialSelector


func _enter_tree() -> void:
	print("Industrial Robot Interface plugin loaded")
	print("  Available backends: MockIndustrial")
	if MotomanBridge.is_available():
		print("  Available backends: MOTOMAN (INRC4)")


func _exit_tree() -> void:
	if _selector_instance:
		_selector_instance.queue_free()
	print("Industrial Robot Interface plugin unloaded")


## ===== Selector Panel =====

## Show the industrial robot selector dialog
func show_selector() -> IndustrialSelector:
	var selector = IndustrialSelector.new()
	get_editor_interface().get_base_control().add_child(selector)
	selector.backend_selected.connect(_on_backend_selected)
	selector.cancelled.connect(_on_selector_cancelled)
	_selector_instance = selector
	return selector


func _on_backend_selected(backend_id: String) -> void:
	print("Industrial backend selected: ", backend_id)
	_selector_instance = null


func _on_selector_cancelled() -> void:
	print("Industrial backend selection cancelled")
	_selector_instance = null


## ===== Backend Factory =====

## Create an industrial backend by name
static func create_backend(backend_id: String, config: Dictionary) -> IndustrialBackend:
	match backend_id:
		"MockIndustrial":
			var backend = MockIndustrial.new()
			backend.initialize(config)
			return backend
		"MOTOMAN":
			var backend = MotomanBridge.new()
			backend.initialize(config)
			return backend
		_:
			push_warning("Industrial plugin: unknown backend ", backend_id, ", using MockIndustrial")
			var backend = MockIndustrial.new()
			backend.initialize(config)
			return backend


## Get list of available backends
static func get_available_backends() -> Array:
	var available = ["MockIndustrial"]
	if MotomanBridge.is_available():
		available.append("MOTOMAN")
	return available


## Get backend info
static func get_backend_info(backend_id: String) -> Dictionary:
	match backend_id:
		"MockIndustrial":
			return {
				"name": MockIndustrial.get_backend_name(),
				"description": MockIndustrial.get_backend_description(),
				"available": MockIndustrial.is_available(),
				"requirements": MockIndustrial.get_requirements()
			}
		"MOTOMAN":
			return {
				"name": MotomanBridge.get_backend_name(),
				"description": MotomanBridge.get_backend_description(),
				"available": MotomanBridge.is_available(),
				"requirements": MotomanBridge.get_requirements()
			}
		_:
			return {}


## ===== Joint Trajectory Handler =====

## Create a new joint trajectory handler
static func create_trajectory_handler() -> JointTrajectoryHandler:
	return JointTrajectoryHandler.new()


## ===== Robot Status Monitor =====

## Create a new robot status monitor
static func create_status_monitor() -> RobotStatusMonitor:
	return RobotStatusMonitor.new()


## ===== Utility =====

## Check if industrial plugin has any available backends
static func has_available_backends() -> bool:
	return MockIndustrial.is_available() or MotomanBridge.is_available()


## Get plugin version
static func get_version() -> String:
	return "1.0.0"