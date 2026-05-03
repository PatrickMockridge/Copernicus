# isaac_gym_task.gd
# Isaac Gym task wrapper for multi-robot GPU training
# Provides pre-built RL environments for robotics

class_name IsaacGymTask
extends RefCounted


## ===== Task Configuration =====

var _task_name: String = ""
var _num_envs: int = 4096  # Default 4096 environments
var _num_obs: int = 0
var _num_actions: int = 0
var _device: String = "cuda:0"


## ===== Observation/Action Spaces =====

var _observation_space: Array = []  # Shape of observation
var _action_space: Array = []      # Shape of action


## ===== Training State =====

var _observations: Array = []
var _rewards: Array = []
var _dones: Array = []
var _episode_count: int = 0


## ===== Signals =====

signal task_reset()
signal episode_complete(total_reward: float)
signal training_step(step: int, mean_reward: float)
signal task_error(message: String)


## ===== Static Methods =====

static func is_isaac_gym_available() -> bool:
	# Check if Isaac Gym Python package is available
	var result = OS.execute("python3", ["-c", "import isaacgym; print('available')"], [], true)
	return result == OK


static func get_available_tasks() -> Array:
	# Return list of pre-built Isaac Gym tasks
	return [
		"shadow_hand",
		"anymal",
		"allegro_hand",
		"cartpole",
		"ball_balance",
		"quadcopter",
		"franka_cube",
		"kortex_robot"
	]


static func get_task_description(task_name: String) -> String:
	var descriptions = {
		"shadow_hand": "Dexterous hand manipulation - pick and place objects",
		"anymal": "Quadruped robot locomotion over rough terrain",
		"allegro_hand": "Shadow Hand-style dextrous manipulation",
		"cartpole": "Classic control task - balance pole on cart",
		"ball_balance": "Robot eye-hand coordination - balance ball on tray",
		"quadcopter": "Multi-rotor flight control",
		"franka_cube": "Pick and place with Franka Panda arm",
		"kortex_robot": "Kinova Kortex arm manipulation"
	}
	return descriptions.get(task_name, "Unknown task")


## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_task_name = config.get("task_name", "cartpole")
	_num_envs = config.get("num_envs", 4096)
	_num_obs = config.get("num_obs", 0)
	_num_actions = config.get("num_actions", 0)
	_device = config.get("device", "cuda:0")

	# Initialize the task via Python subprocess
	var result = _init_task()
	return result


func shutdown() -> void:
	_send_command({"cmd": "shutdown"})


## ===== Reset =====

func reset() -> Array:
	# Reset all environments and return initial observations
	var result = _send_command({
		"cmd": "reset",
		"num_envs": _num_envs
	})

	if result.get("status") == "ok":
		_observations = result.get("observations", [])
		_rewards.clear()
		_dones.clear()
		task_reset.emit()
		return _observations

	task_error.emit("Reset failed: " + result.get("message", "Unknown"))
	return []


## ===== Step =====

func step(actions: Array) -> Dictionary:
	# Execute one step across all environments
	# actions: Array of action vectors (one per environment)

	var result = _send_command({
		"cmd": "step",
		"actions": actions
	})

	if result.get("status") == "ok":
		_observations = result.get("observations", [])
		var rewards = result.get("rewards", [])
		var dones = result.get("dones", [])

		# Track episode completion
		for i in range(rewards.size()):
			_rewards.append(rewards[i])
			_dones.append(dones[i])

			if dones[i]:
				var episode_reward = _calculate_episode_reward(i)
				episode_complete.emit(episode_reward)

		var mean_reward = _calculate_mean_reward()

		return {
			"observations": _observations,
			"rewards": rewards,
			"dones": dones,
			"mean_reward": mean_reward
		}

	return {
		"observations": [],
		"rewards": [],
		"dones": [],
		"mean_reward": 0.0
	}


## ===== Observation =====

func get_observations() -> Array:
	return _observations.duplicate()


func get_observation_shape() -> Array:
	return _observation_space


## ===== Actions =====

func get_action_shape() -> Array:
	return _action_space


func set_action_space(num_actions: int) -> void:
	_action_space = [num_actions]


## ===== GPU Memory =====

## Reset buffers on GPU
func reset_buffers() -> void:
	_send_command({"cmd": "reset_buffers"})


## ===== Domain Randomization =====

func set_dynamics_randomization(enabled: bool) -> void:
	_send_command({
		"cmd": "set_dynamics_randomization",
		"enabled": enabled
	})


func set_observation_noise(noise_scale: float) -> void:
	_send_command({
		"cmd": "set_observation_noise",
		"noise_scale": noise_scale
	})


## ===== Physics =====

func set_physics_parameters(config: Dictionary) -> void:
	_send_command({
		"cmd": "set_physics_params",
		"config": config
	})


## ===== Cameras =====

func get_camera_images(env_ids: Array = []) -> Dictionary:
	var result = _send_command({
		"cmd": "get_camera_images",
		"env_ids": env_ids
	})
	return result.get("images", {})


func enable_rendering(enabled: bool) -> void:
	_send_command({
		"cmd": "enable_rendering",
		"enabled": enabled
	})


## ===== Statistics =====

func get_episode_rewards() -> Array:
	return _rewards.duplicate()


func get_mean_reward() -> float:
	return _calculate_mean_reward()


func get_episode_count() -> int:
	return _episode_count


## ===== Internal Methods =====

func _init_task() -> bool:
	var result = _send_command({
		"cmd": "init_task",
		"task_name": _task_name,
		"num_envs": _num_envs,
		"device": _device
	})

	if result.get("status") == "ok":
		_observation_space = result.get("obs_space", [])
		_action_space = result.get("action_space", [])
		return true

	task_error.emit("Task init failed: " + result.get("message", "Unknown"))
	return false


func _send_command(cmd: Dictionary) -> Dictionary:
	var temp_dir = "/tmp/copernicus_isaac_%d" % OS.get_process_id()
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
	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/backends/isaac_gym/isaac_gym_task.py")
	var escaped_script = script_path.replace("\\", "\\\\").replace("'", "\\'")

	var output = []
	OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('isaac_gym_task', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with open('%s', 'r') as f:
    cmd = json.load(f)

task = module.IsaacGymTaskScript()
task.process_command(cmd)

with open('%s', 'w') as f:
    json.dump(task._last_response, f)
""" % (escaped_script, escaped_script, cmd_file.replace("\\", "\\\\").replace("'", "\\'"), resp_file.replace("\\", "\\\\").replace("'", "\\'"))], output, true)

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


func _calculate_episode_reward(episode_idx: int) -> float:
	# Sum rewards for a specific episode
	var total = 0.0
	var found_done = false
	for i in range(_rewards.size()):
		if _dones[i]:
			if not found_done and i >= episode_idx:
				found_done = true
			elif found_done:
				break
		elif found_done:
			total += _rewards[i]
	return total


func _calculate_mean_reward() -> float:
	if _rewards.size() == 0:
		return 0.0
	var total = 0.0
	for r in _rewards:
		total += r
	return total / _rewards.size()