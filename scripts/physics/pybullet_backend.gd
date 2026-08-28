# pybullet_backend.gd
# Physics backend using PyBullet via subprocess
# Research-grade physics using Bullet Physics

class_name PyBulletBackend
extends PhysicsBackend

## PyBullet subprocess physics
## Uses Python's PyBullet library for accurate physics simulation

var _bridge: PythonBridge
var _is_simulating: bool = false

var _body_ids: Dictionary = {}  # name -> pybullet body id
var _next_body_id: int = 1

var _gravity: Vector3 = Vector3(0, -9.81, 0)
var _timestep: float = 0.001

var _pending_commands: Array = []
var _pending_results: Dictionary = {}


static func get_module_name() -> String:
	return "PyBullet"


static func get_module_description() -> String:
	return "Bullet Physics via Python/PyBullet. Research-grade accuracy for robotics simulation."


static func is_available() -> bool:
	# Check if python3 with pybullet is available
	var output = []
	var ret = OS.execute("python3", ["-c", "import pybullet; print('ok')"], output, false)
	return ret == 0 and output.size() > 0 and output[0].strip_edges() == "ok"


static func get_requirements() -> String:
	return "Requires: pip install pybullet"



static func get_module_category() -> String:
	return "physics"

static func _static_init():
	ModuleRegistry.register("physics", "PyBulletBackend", preload("res://scripts/physics/pybullet_backend.gd"))
## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	if not is_available():
		backend_error.emit("PyBullet not available. Install with: pip install pybullet")
		backend_initialized.emit(false)
		return false

	_gravity = config.get("gravity", Vector3(0, -9.81, 0))
	_timestep = config.get("timestep", 0.001)

	_bridge = PythonBridge.new()
	var script_path = ProjectSettings.globalize_path("res://scripts/physics/pybullet_bridge.py")
	if not _bridge.start(script_path):
		backend_error.emit("Failed to start PyBullet bridge")
		backend_initialized.emit(false)
		return false

	var init_result = _bridge.send({
		"cmd": "init",
		"gravity": [_gravity.x, _gravity.y, _gravity.z],
		"timestep": _timestep
	})

	if init_result.get("status") != "ok":
		backend_error.emit("PyBullet init failed: " + init_result.get("message", "unknown"))
		backend_initialized.emit(false)
		return false

	_is_simulating = true
	backend_initialized.emit(true)
	return true


func is_running() -> bool:
	return _is_simulating and _bridge and _bridge.is_bridge_connected()


func shutdown() -> void:
	_is_simulating = false
	if _bridge:
		_bridge.shutdown()
		_bridge = null
	_body_ids.clear()
	_pending_commands.clear()
	_pending_results.clear()

func step_simulation(delta: float) -> void:
	if not _is_simulating:
		return

	_send_command({"cmd": "step"})

	# Emit step signal (PyBullet handles timing internally)
	simulation_stepped.emit(delta)


func get_body_state(body_name: String) -> Dictionary:
	var result = _send_command({
		"cmd": "get_state",
		"name": body_name
	})

	if result.get("status") != "ok":
		return {}

	var data = result.get("data", {})
	return {
		"position": _list_to_vec3(data.get("pos", [0, 0, 0])),
		"rotation": _list_to_quat(data.get("quat", [0, 0, 0, 1])),
		"linear_velocity": _list_to_vec3(data.get("vel", [0, 0, 0])),
		"angular_velocity": _list_to_vec3(data.get("avel", [0, 0, 0])),
		"force": _list_to_vec3(data.get("force", [0, 0, 0]))
	}


func get_all_states() -> Dictionary:
	var result = _send_command({"cmd": "get_all_states"})

	if result.get("status") != "ok":
		return {}

	var states = {}
	var data = result.get("data", {})

	for body_name in _body_ids.keys():
		var body_data = data.get(body_name, {})
		states[body_name] = {
			"position": _list_to_vec3(body_data.get("pos", [0, 0, 0])),
			"rotation": _list_to_quat(body_data.get("quat", [0, 0, 0, 1])),
			"linear_velocity": _list_to_vec3(body_data.get("vel", [0, 0, 0])),
			"angular_velocity": _list_to_vec3(body_data.get("avel", [0, 0, 0]))
		}

	return states


## ===== Body Management =====

func create_rigid_body(name: String, config: Dictionary) -> bool:
	var cmd = {
		"cmd": "create_body",
		"name": name,
		"type": config.get("type", "box"),
		"pos": _vec3_to_list(config.get("position", Vector3.ZERO)),
		"quat": _quat_to_list(config.get("rotation", Quaternion.IDENTITY)),
		"mass": config.get("mass", 1.0)
	}

	# Type-specific params
	match config.get("type", "box"):
		"box":
			cmd["size"] = _vec3_to_list(config.get("size", Vector3(0.5, 0.5, 0.5)))
		"sphere":
			cmd["radius"] = config.get("radius", 0.5)
		"cylinder":
			cmd["radius"] = config.get("radius", 0.25)
			cmd["length"] = config.get("length", 0.5)

	var result = _send_command(cmd)

	if result.get("status") == "ok":
		_body_ids[name] = _next_body_id
		_next_body_id += 1
		return true

	return false


func remove_body(name: String) -> void:
	if not _body_ids.has(name):
		return

	_send_command({"cmd": "remove_body", "name": name})
	_body_ids.erase(name)


## ===== Forces =====

func apply_force(body_name: String, force: Vector3, position: Vector3 = Vector3.ZERO) -> void:
	_send_command({
		"cmd": "apply_force",
		"name": body_name,
		"force": _vec3_to_list(force),
		"pos": _vec3_to_list(position)
	})


func apply_torque(body_name: String, torque: Vector3) -> void:
	_send_command({
		"cmd": "apply_torque",
		"name": body_name,
		"torque": _vec3_to_list(torque)
	})


func reset_forces(body_name: String) -> void:
	_send_command({"cmd": "reset_forces", "name": body_name})


## ===== Joints =====

func create_joint(name: String, config: Dictionary) -> bool:
	var cmd = {
		"cmd": "create_joint",
		"name": name,
		"type": config.get("type", "fixed"),
		"parent": config.get("parent", ""),
		"child": config.get("child", ""),
		"anchor_parent": _vec3_to_list(config.get("anchor_parent", Vector3.ZERO)),
		"anchor_child": _vec3_to_list(config.get("anchor_child", Vector3.ZERO))
	}

	if config.has("axis"):
		cmd["axis"] = _vec3_to_list(config.get("axis"))

	var result = _send_command(cmd)
	return result.get("status") == "ok"


func remove_joint(name: String) -> void:
	_send_command({"cmd": "remove_joint", "name": name})


## ===== Collision =====

func set_collision(body1: String, body2: String, enabled: bool) -> void:
	_send_command({
		"cmd": "set_collision",
		"body1": body1,
		"body2": body2,
		"enabled": enabled
	})


func get_contacts(body_name: String) -> Array:
	var result = _send_command({"cmd": "get_contacts", "name": body_name})

	if result.get("status") != "ok":
		return []

	var contacts = []
	for contact in result.get("contacts", []):
		contacts.append({
			"position": _list_to_vec3(contact.get("pos", [0, 0, 0])),
			"normal": _list_to_vec3(contact.get("normal", [0, 0, 0])),
			"depth": contact.get("depth", 0.0),
			"other_body": contact.get("other", "")
		})

	return contacts


## ===== Internal Helpers =====

func _send_command(cmd: Dictionary) -> Dictionary:
	if not _bridge or not _bridge.is_bridge_connected():
		return {"status": "error", "message": "Bridge not connected"}
	return _bridge.send(cmd)
func _vec3_to_list(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _list_to_vec3(l: Array) -> Vector3:
	if l.size() >= 3:
		return Vector3(l[0], l[1], l[2])
	return Vector3.ZERO


func _quat_to_list(q: Quaternion) -> Array:
	return [q.x, q.y, q.z, q.w]


func _list_to_quat(l: Array) -> Quaternion:
	if l.size() >= 4:
		return Quaternion(l[0], l[1], l[2], l[3])
	return Quaternion.IDENTITY
