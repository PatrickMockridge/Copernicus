# isaac_gym_replicator.gd
# Omniverse Replicator integration for synthetic data generation
# Provides SDF-based data capture during Isaac Gym training

class_name IsaacGymReplicator
extends RefCounted


## ===== Replicator Configuration =====

var _enabled: bool = false
var _output_dir: String = "cache/replicator/"
var _capture_interval: int = 100  # Capture every N steps
var _capture_types: Array = ["rgb", "depth", "semantic", "bounding_box"]


## ===== Camera Configuration =====

var _camera_resolution: Array = [640, 480]
var _camera_fov: float = 60.0
var _camera_count: int = 1


## ===== Annotation Types =====

var _annotators: Array = []
var _annotation_labels: Dictionary = {}


## ===== Signals =====

signal frame_captured(frame_id: int, annotator_type: String)
signal replication_complete(total_frames: int)
signal replicator_error(message: String)


## ===== Static Methods =====

static func is_replicator_available() -> bool:
	# Check if Omniverse Replicator is available
	var result = OS.execute("python3", ["-c", "import omni.replicator; print('available')"], [], true)
	return result == OK


static func get_supported_formats() -> Array:
	return [
		"kittof",    # KITTI format for autonomous vehicles
		"coco",      # COCO format for object detection
		"yolo",      # YOLO format
		"sdf",       # SDF annotations for Isaac Sim
		"raw"        # Raw numpy arrays
	]


## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_enabled = config.get("enabled", true)
	_output_dir = config.get("output_dir", "cache/replicator/")
	_capture_interval = config.get("capture_interval", 100)
	_capture_types = config.get("capture_types", _capture_types)
	_camera_resolution = config.get("resolution", [640, 480])
	_camera_fov = config.get("fov", 60.0)
	_camera_count = config.get("camera_count", 1)

	# Initialize Python-side replicator
	var result = _init_replicator()
	return result


func shutdown() -> void:
	_send_command({"cmd": "shutdown"})


## ===== Annotators =====

func create_annotator(annotator_type: String, label: String = "") -> bool:
	var result = _send_command({
		"cmd": "create_annotator",
		"type": annotator_type,
		"label": label
	})

	if result.get("status") == "ok":
		_annotators.append(annotator_type)
		if label != "":
			_annotation_labels[annotator_type] = label
		return true

	replicator_error.emit("Failed to create annotator: " + result.get("message", "unknown"))
	return false


func create_semantic_segmentation(schema_file: String = "") -> bool:
	var result = _send_command({
		"cmd": "create_semantic_segmentation",
		"schema_file": schema_file
	})

	if result.get("status") == "ok":
		_annotators.append("semantic")
		return true

	replicator_error.emit("Failed to create semantic annotator: " + result.get("message", "unknown"))
	return false


func create_bounding_box_2d() -> bool:
	return create_annotator("bounding_box_2d")


func create_bounding_box_3d() -> bool:
	return create_annotator("bounding_box_3d")


## ===== Camera Setup =====

func setup_cameras(config: Dictionary) -> Dictionary:
	var result = _send_command({
		"cmd": "setup_cameras",
		"config": config
	})

	if result.get("status") == "ok":
		_camera_count = config.get("count", _camera_count)
		return result.get("cameras", {})

	replicator_error.emit("Failed to setup cameras: " + result.get("message", "unknown"))
	return {}


func set_camera_pose(camera_id: int, position: Vector3, rotation: Quaternion) -> bool:
	var result = _send_command({
		"cmd": "set_camera_pose",
		"camera_id": camera_id,
		"position": [position.x, position.y, position.z],
		"rotation": [rotation.x, rotation.y, rotation.z, rotation.w]
	})

	return result.get("status") == "ok"


## ===== Domain Randomization =====

func enable_domain_randomization(enabled: bool) -> void:
	_send_command({
		"cmd": "enable_domain_randomization",
		"enabled": enabled
	})


func add_color_randomization(property: String, min_val: float, max_val: float) -> void:
	_send_command({
		"cmd": "add_color_randomization",
		"property": property,
		"min": min_val,
		"max": max_val
	})


func add_transform_randomization(property: String, min_val: float, max_val: float) -> void:
	_send_command({
		"cmd": "add_transform_randomization",
		"property": property,
		"min": min_val,
		"max": max_val
	})


func add_light_randomization() -> void:
	_send_command({"cmd": "add_light_randomization"})


func add_materials_randomization() -> void:
	_send_command({"cmd": "add_materials_randomization"})


## ===== Data Capture =====

func capture_frame(env_id: int = 0) -> Dictionary:
	var result = _send_command({
		"cmd": "capture_frame",
		"env_id": env_id
	})

	if result.get("status") == "ok":
		var frame_id = result.get("frame_id", 0)
		var annotator = result.get("annotator", "unknown")
		frame_captured.emit(frame_id, annotator)
		return result.get("data", {})

	return {}


func save_annotations(frame_id: int, output_format: String = "coco") -> bool:
	var result = _send_command({
		"cmd": "save_annotations",
		"frame_id": frame_id,
		"format": output_format
	})

	return result.get("status") == "ok"


func batch_capture(num_frames: int, env_ids: Array = []) -> Array:
	var result = _send_command({
		"cmd": "batch_capture",
		"num_frames": num_frames,
		"env_ids": env_ids
	})

	if result.get("status") == "ok":
		var frames = result.get("frames", [])
		replication_complete.emit(frames.size())
		return frames

	return []


## ===== Writer Configuration =====

func configure_writer(writer_type: String, output_dir: String, config: Dictionary = {}) -> bool:
	var result = _send_command({
		"cmd": "configure_writer",
		"writer_type": writer_type,
		"output_dir": output_dir,
		"config": config
	})

	return result.get("status") == "ok"


func start_async_recording() -> void:
	_send_command({"cmd": "start_async_recording"})


func stop_async_recording() -> void:
	_send_command({"cmd": "stop_async_recording"})


## ===== SDF Integration =====

func get_sdf_annotations(env_id: int = 0) -> Dictionary:
	var result = _send_command({
		"cmd": "get_sdf_annotations",
		"env_id": env_id
	})

	return result.get("sdf_data", {})


func export_sdf_to_isaac(source_file: String, target_path: String) -> bool:
	var result = _send_command({
		"cmd": "export_sdf_to_isaac",
		"source": source_file,
		"target": target_path
	})

	return result.get("status") == "ok"


## ===== Statistics =====

func get_capture_count() -> int:
	var result = _send_command({"cmd": "get_capture_count"})
	return result.get("count", 0)


func get_annotation_stats() -> Dictionary:
	var result = _send_command({"cmd": "get_annotation_stats"})
	return result.get("stats", {})


## ===== Internal Methods =====

func _init_replicator() -> bool:
	var result = _send_command({
		"cmd": "init_replicator",
		"output_dir": _output_dir,
		"capture_interval": _capture_interval,
		"capture_types": _capture_types
	})

	if result.get("status") == "ok":
		_enabled = true
		return true

	# Replicator may not be available - that's ok
	replicator_error.emit("Replicator init failed (may not be installed): " + result.get("message", "unknown"))
	return false


func _send_command(cmd: Dictionary) -> Dictionary:
	var temp_dir = "/tmp/copernicus_replicator_%d" % OS.get_process_id()
	var cmd_file = temp_dir + "/cmd.json"
	var resp_file = temp_dir + "/resp.json"

	OS.execute("mkdir", ["-p", temp_dir], [], true)

	# Write command
	var f = FileAccess.open(cmd_file, FileAccess.WRITE)
	if f == null:
		return {"status": "error", "message": "Failed to write command"}
	f.store_string(JSON.stringify(cmd))
	f.close()

	# Execute Python script
	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/backends/isaac_gym/isaac_gym_replicator.py")
	if not FileAccess.file_exists(script_path):
		return {"status": "error", "message": "Replicator script not found"}
	var escaped_script = script_path.replace("\\", "\\\\").replace("'", "\\'")

	var output = []
	OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('isaac_gym_replicator', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with open('%s', 'r') as f:
    cmd = json.load(f)

replicator = module.IsaacGymReplicatorScript()
replicator.process_command(cmd)

with open('%s', 'w') as f:
    json.dump(replicator._last_response, f)
""" % [escaped_script, escaped_script, cmd_file.replace("\\", "\\\\").replace("'", "\\'"), resp_file.replace("\\", "\\\\").replace("'", "\\'")]], output, true)

	# Read response
	f = FileAccess.open(resp_file, FileAccess.READ)
	if f:
		var content = f.get_as_text()
		f.close()
		OS.execute("rm", ["-rf", temp_dir], [], true)
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			return parsed

	return {"status": "error", "message": "No response"}
