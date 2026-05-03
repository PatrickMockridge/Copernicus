# sac_learner.gd
# Soft Actor-Critic (SAC) learner backend
# Off-policy policy gradient RL via PyTorch with CUDA support

class_name SACLearner
extends GPUBackend

## SAC configuration
var _state_dim: int = 0
var _action_dim: int = 0
var _hidden_dim: int = 128
var _learning_rate: float = 0.0003
var _gamma: float = 0.99
var _tau: float = 0.005  # Target network update rate
var _alpha: float = 0.2  # Entropy coefficient
var _auto_alpha: bool = true  #自动调节 entropy temperature

## Training state
var _total_steps: int = 0
var _episode_count: int = 0
var _last_loss: float = 0.0
var _policy_entropy: float = 0.0
var _mean_reward: float = 0.0
var _alpha_value: float = 0.2

## Python subprocess communication
var _python_process: int = -1


static func get_backend_name() -> String:
	return "SAC (Soft Actor-Critic)"


static func get_backend_description() -> String:
	return "Off-policy policy gradient RL with entropy maximization. Good for exploration."


static func is_available() -> bool:
	var output = []; var result = OS.execute("python3", ["-c", "import torch; print(torch.__version__)"], output, true)
	return result == 0


static func get_requirements() -> String:
	return "PyTorch: pip install torch"


func initialize(config: Dictionary) -> bool:
	_state_dim = config.get("state_dim", 24)
	_action_dim = config.get("action_dim", 4)
	_hidden_dim = config.get("hidden_dim", 128)
	_learning_rate = config.get("learning_rate", 0.0003)
	_gamma = config.get("gamma", 0.99)
	_tau = config.get("tau", 0.005)
	_alpha = config.get("alpha", 0.2)
	_auto_alpha = config.get("auto_alpha", true)
	_device = config.get("device", "cuda" if check_cuda_available() else "cpu")

	_initialized = true
	backend_ready.emit()
	return true


func shutdown() -> void:
	_initialized = false


func train_step(observations: Array, actions: Array, rewards: Array,
                next_observations: Array, dones: Array) -> Dictionary:
	if observations.is_empty() or not _initialized:
		return {"loss": 0.0, "entropy": 0.0, "mean_reward": 0.0}

	# Build JSON command
	var cmd = {
		"cmd": "sac_train_step",
		"observations": observations,
		"actions": actions,
		"rewards": rewards,
		"next_observations": next_observations,
		"dones": dones,
		"gamma": _gamma,
		"tau": _tau,
		"alpha": _alpha
	}

	var response = _send_command(cmd)
	if response.get("status") == "ok":
		_last_loss = response.get("loss", 0.0)
		_policy_entropy = response.get("entropy", 0.0)
		_mean_reward = response.get("mean_reward", 0.0)
		_alpha_value = response.get("alpha", _alpha)
		_total_steps += observations.size()
		training_step.emit(_last_loss)

		if response.get("done", false):
			_episode_count += 1
			episode_complete.emit(_mean_reward)

	return {
		"loss": _last_loss,
		"entropy": _policy_entropy,
		"mean_reward": _mean_reward,
		"alpha": _alpha_value,
		"done": response.get("done", false)
	}


func get_action(observations: Array, deterministic: bool = false) -> Dictionary:
	if not _initialized:
		return {"action": 0, "log_prob": 0.0}

	var cmd = {
		"cmd": "sac_get_action",
		"observations": observations,
		"deterministic": deterministic
	}

	var response = _send_command(cmd)
	if response.get("status") == "ok":
		return {
			"action": response.get("action", 0),
			"log_prob": response.get("log_prob", 0.0)
		}
	return {"action": 0, "log_prob": 0.0}


func _send_command(cmd: Dictionary) -> Dictionary:
	var json_str = JSON.stringify(cmd)

	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/pytorch_learning_node.py")
	var output = []

	var python_code = """
import sys, json, os
sys.path.insert(0, os.path.dirname('%s'))

import importlib.util
spec = importlib.util.spec_from_file_location('pytorch_node', '%s')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

cmd = json.loads('''%s''')
action = cmd.get('cmd', '')

if action == 'sac_train_step':
    result = module.sac_train_step(cmd)
    print(json.dumps(result))
elif action == 'sac_get_action':
    result = module.sac_get_action(cmd)
    print(json.dumps(result))
else:
    print(json.dumps({'status': 'error', 'message': 'unknown cmd'}))
""" % (script_path.replace("\\", "\\\\"), script_path.replace("\\", "\\\\"), json_str.replace("\\", "\\\\").replace("'", "\\'"))

	var result = OS.execute("python3", ["-c", python_code], output, true)

	if result == 0 and output.size() > 0:
		var parsed = JSON.parse_string(output[0])
		if parsed is Dictionary:
			return parsed
	return {"status": "error"}


func save_model(path: String) -> bool:
	if not _initialized:
		return false

	var cmd = {"cmd": "sac_save", "path": path}
	var response = _send_command(cmd)
	return response.get("status") == "ok"


func load_model(path: String) -> bool:
	if not _initialized:
		return false

	var cmd = {"cmd": "sac_load", "path": path}
	var response = _send_command(cmd)
	return response.get("status") == "ok"


func get_model_info() -> Dictionary:
	return {
		"device": _device,
		"state_dim": _state_dim,
		"action_dim": _action_dim,
		"hidden_dim": _hidden_dim,
		"learning_rate": _learning_rate,
		"gamma": _gamma,
		"tau": _tau,
		"alpha": _alpha_value,
		"total_steps": _total_steps,
		"episode_count": _episode_count,
		"last_loss": _last_loss,
		"policy_entropy": _policy_entropy,
		"mean_reward": _mean_reward
	}