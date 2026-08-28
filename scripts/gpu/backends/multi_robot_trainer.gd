# multi_robot_trainer.gd
# Multi-robot GPU training coordinator
# Manages distributed training across Isaac Gym environments

class_name MultiRobotTrainer
extends RefCounted


## ===== Training Configuration =====

var _num_robots: int = 1
var _training_algorithm: String = "PPO"  # PPO, SAC, TD3
var _device: String = "cuda:0"
var _checkpoint_dir: String = "cache/checkpoints/"


## ===== Training State =====

var _is_training: bool = false
var _current_step: int = 0
var _total_episodes: int = 0
var _tasks: Array = []  # IsaacGymTask instances


## ===== PPO Configuration =====

var _ppo_config: Dictionary = {
	"lr": 0.0003,
	"gamma": 0.99,
	"k_epochs": 4,
	"eps_clip": 0.2,
	"entropy_coef": 0.01,
	"value_coef": 0.5,
	"hidden_dim": 128
}


## ===== SAC Configuration =====

var _sac_config: Dictionary = {
	"lr": 0.0003,
	"gamma": 0.99,
	"tau": 0.005,
	"entropy_coef": 0.2,
	"hidden_dim": 128
}


## ===== Signals =====

signal training_started()
signal training_stopped()
signal step_complete(step: int, mean_reward: float, info: Dictionary)
signal episode_complete(robot_id: int, episode_reward: float, episode_length: int)
signal checkpoint_saved(path: String)
signal training_error(message: String)


## ===== Static Methods =====

static func get_supported_algorithms() -> Array:
	return ["PPO", "SAC", "TD3"]


static func get_algorithm_description(algorithm: String) -> String:
	var descriptions = {
		"PPO": "Proximal Policy Optimization - stable policy gradient for continuous control",
		"SAC": "Soft Actor-Critic - maximum entropy RL for exploration",
		"TD3": "Twin Delayed DDPG - addresses Q-function overestimation"
	}
	return descriptions.get(algorithm, "Unknown algorithm")


## ===== Initialization =====

func initialize(config: Dictionary) -> bool:
	_num_robots = config.get("num_robots", 1)
	_training_algorithm = config.get("algorithm", "PPO")
	_device = config.get("device", "cuda:0")
	_checkpoint_dir = config.get("checkpoint_dir", "cache/checkpoints/")

	# Parse algorithm-specific config
	if config.has("ppo_config"):
		_ppo_config.merge(config["ppo_config"], true)
	if config.has("sac_config"):
		_sac_config.merge(config["sac_config"], true)

	# Initialize coordinator via Python
	var result = _init_coordinator()
	return result


func shutdown() -> void:
	stop_training()
	_send_command({"cmd": "shutdown"})


## ===== Task Management =====

func add_task(task: IsaacGymTask) -> bool:
	if not task:
		return false

	_tasks.append(task)
	return _send_command({
		"cmd": "add_task",
		"task_name": task._task_name,
		"num_envs": task._num_envs
	}).get("status") == "ok"


func remove_task(task_name: String) -> bool:
	var result = _send_command({
		"cmd": "remove_task",
		"task_name": task_name
	})

	if result.get("status") == "ok":
		_tasks = _tasks.filter(func(t): return t._task_name != task_name)
		return true
	return false


func get_task(task_name: String) -> IsaacGymTask:
	for task in _tasks:
		if task._task_name == task_name:
			return task
	return null


func get_all_tasks() -> Array:
	return _tasks.duplicate()


## ===== Training Control =====

func start_training() -> bool:
	if _is_training:
		return false

	var result = _send_command({
		"cmd": "start_training",
		"algorithm": _training_algorithm
	})

	if result.get("status") == "ok":
		_is_training = true
		training_started.emit()
		return true

	training_error.emit("Failed to start training: " + result.get("message", "unknown"))
	return false


func stop_training() -> bool:
	if not _is_training:
		return true

	var result = _send_command({"cmd": "stop_training"})

	if result.get("status") == "ok":
		_is_training = false
		training_stopped.emit()
		return true

	return false


func pause_training() -> void:
	_send_command({"cmd": "pause_training"})
	_is_training = false


func resume_training() -> void:
	_send_command({"cmd": "resume_training"})
	_is_training = true


## ===== Training Step =====

func train_step(delta: float = 0.02) -> Dictionary:
	if not _is_training or _tasks.is_empty():
		return {"mean_reward": 0.0, "done": false}

	# Collect actions from all tasks
	var all_observations = []
	var all_actions = []

	for task in _tasks:
		var obs = task.get_observations()
		if not obs.is_empty():
			# Get action from learner (policy)
			var action = _get_policy_action(obs)
			all_observations.append(obs)
			all_actions.append(action)

	# Step all environments
	var total_reward = 0.0
	var total_dones = 0

	for task in _tasks:
		var result = task.step(all_actions[_tasks.find(task)])
		total_reward += result.get("mean_reward", 0.0)
		if result.get("dones", []).size() > 0:
			total_dones += result["dones"].count(true)

	_current_step += 1
	var mean_reward = total_reward / max(_tasks.size(), 1)

	var info = {
		"total_dones": total_dones,
		"num_active_tasks": _tasks.size()
	}

	step_complete.emit(_current_step, mean_reward, info)
	return {"mean_reward": mean_reward, "done": total_dones > 0, "info": info}


## ===== Policy Actions =====

func _get_policy_action(observations: Array) -> Array:
	# Get action from the training algorithm
	var result = _send_command({
		"cmd": "get_action",
		"observations": observations
	})

	if result.get("status") == "ok":
		return result.get("actions", [])
	return []


func update_policy(observations: Array, actions: Array, rewards: Array, dones: Array) -> float:
	# Update policy using collected experience
	var result = _send_command({
		"cmd": "update_policy",
		"observations": observations,
		"actions": actions,
		"rewards": rewards,
		"dones": dones
	})

	if result.get("status") == "ok":
		return result.get("loss", 0.0)
	return 0.0


## ===== Checkpointing =====

func save_checkpoint(name: String = "") -> String:
	if name == "":
		name = "checkpoint_%d_%d" % [Time.get_unix_time_from_system(), _current_step]

	var checkpoint_path = _checkpoint_dir.path_join(name + ".pt")
	var result = _send_command({
		"cmd": "save_checkpoint",
		"path": checkpoint_path
	})

	if result.get("status") == "ok":
		checkpoint_saved.emit(checkpoint_path)
		return checkpoint_path

	training_error.emit("Failed to save checkpoint: " + result.get("message", "unknown"))
	return ""


func load_checkpoint(path: String) -> bool:
	var result = _send_command({
		"cmd": "load_checkpoint",
		"path": path
	})

	return result.get("status") == "ok"


func get_checkpoint_info(path: String) -> Dictionary:
	var result = _send_command({
		"cmd": "get_checkpoint_info",
		"path": path
	})
	return result.get("info", {})


## ===== Statistics =====

func get_training_stats() -> Dictionary:
	var result = _send_command({"cmd": "get_training_stats"})
	return result.get("stats", {
		"current_step": _current_step,
		"total_episodes": _total_episodes,
		"is_training": _is_training
	})


func get_learning_curve(num_points: int = 100) -> Array:
	var result = _send_command({
		"cmd": "get_learning_curve",
		"num_points": num_points
	})
	return result.get("curve", [])


func get_reward_history(window: int = 100) -> Array:
	var result = _send_command({
		"cmd": "get_reward_history",
		"window": window
	})
	return result.get("rewards", [])


## ===== Algorithm Switching =====

func set_algorithm(algorithm: String) -> bool:
	if algorithm not in get_supported_algorithms():
		training_error.emit("Unsupported algorithm: " + algorithm)
		return false

	if _is_training:
		training_error.emit("Cannot switch algorithm while training")
		return false

	_training_algorithm = algorithm
	return true


func get_current_algorithm() -> String:
	return _training_algorithm


func get_algorithm_config() -> Dictionary:
	match _training_algorithm:
		"PPO":
			return _ppo_config
		"SAC":
			return _sac_config
		_:
			return {}


## ===== Multi-Robot Coordination =====

func synchronize_robots() -> void:
	# Synchronize robot states across environments
	_send_command({"cmd": "synchronize_robots"})


func get_robot_state(robot_id: int) -> Dictionary:
	var result = _send_command({
		"cmd": "get_robot_state",
		"robot_id": robot_id
	})
	return result.get("state", {})


func set_robot_goal(robot_id: int, goal: Dictionary) -> bool:
	var result = _send_command({
		"cmd": "set_robot_goal",
		"robot_id": robot_id,
		"goal": goal
	})
	return result.get("status") == "ok"


## ===== Internal Methods =====

func _init_coordinator() -> bool:
	var result = _send_command({
		"cmd": "init_coordinator",
		"num_robots": _num_robots,
		"algorithm": _training_algorithm,
		"device": _device,
		"ppo_config": _ppo_config,
		"sac_config": _sac_config
	})

	return result.get("status") == "ok"


func _send_command(cmd: Dictionary) -> Dictionary:
	var temp_dir = "/tmp/copernicus_trainer_%d" % OS.get_process_id()
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
	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/backends/isaac_gym/multi_robot_trainer.py")
	if not FileAccess.file_exists(script_path):
		return {"status": "error", "message": "Trainer script not found"}
	var escaped_script = script_path.replace("\\", "\\\\").replace("'", "\\'")

	var output = []
	OS.execute("python3", ["-c", """
import sys, os, json
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('multi_robot_trainer', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with open('%s', 'r') as f:
    cmd = json.load(f)

trainer = module.MultiRobotTrainerScript()
trainer.process_command(cmd)

with open('%s', 'w') as f:
    json.dump(trainer._last_response, f)
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
