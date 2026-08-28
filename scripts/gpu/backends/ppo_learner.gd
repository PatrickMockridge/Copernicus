# ppo_learner.gd
# Proximal Policy Optimization (PPO) learner backend
# Policy gradient RL via PyTorch with CUDA support

class_name PPOLearner
extends GPUBackend

## PPO configuration
var _state_dim: int = 0
var _bridge: PythonBridge
var _action_dim: int = 0
var _hidden_dim: int = 128
var _learning_rate: float = 0.0003
var _gamma: float = 0.99
var _epsilon_clip: float = 0.2
var _gae_lambda: float = 0.95
var _update_epochs: int = 10
var _mini_batch_size: int = 64

## Training state
var _total_steps: int = 0
var _episode_count: int = 0
var _last_loss: float = 0.0
var _policy_entropy: float = 0.0
var _mean_reward: float = 0.0

## Python subprocess communication
var _python_process: int = -1


static func get_backend_name() -> String:
	return "PPO (Proximal Policy Optimization)"


static func get_backend_description() -> String:
	return "Policy gradient RL via PPO with clipping. Better for continuous control than DQN."


static func is_available() -> bool:
	var output = []; var result = OS.execute("python3", ["-c", "import torch; print(torch.__version__)"], output, true)
	return result == 0


static func get_requirements() -> String:
	return "PyTorch: pip install torch"


static func check_cuda_available() -> bool:
	var result = OS.execute("nvidia-smi", [], [], true)
	return result == OK


func initialize(config: Dictionary) -> bool:
	_state_dim = config.get("state_dim", 24)
	_action_dim = config.get("action_dim", 4)
	_hidden_dim = config.get("hidden_dim", 128)
	_learning_rate = config.get("learning_rate", 0.0003)
	_gamma = config.get("gamma", 0.99)
	_epsilon_clip = config.get("epsilon_clip", 0.2)
	_gae_lambda = config.get("gae_lambda", 0.95)
	_update_epochs = config.get("update_epochs", 10)
	_device = config.get("device", "cuda" if check_cuda_available() else "cpu")

	_bridge = PythonBridge.new()
	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/pytorch_learning_node.py")
	if not _bridge.start(script_path, 9878):
		push_error("PPOLearner: Failed to start Python bridge")
		return false

	_initialized = true
	backend_ready.emit()
	return true


func shutdown() -> void:
	if _bridge:
		_bridge.shutdown()
		_bridge = null
	_initialized = false


func train_step_ppo(observations: Array, actions: Array, rewards: Array,
                old_log_probs: Array, values: Array, dones: Array) -> Dictionary:
	if observations.is_empty() or not _initialized:
		return {"loss": 0.0, "entropy": 0.0, "mean_reward": 0.0}

	# Build JSON command
	var cmd = {
		"cmd": "ppo_train_step",
		"observations": observations,
		"actions": actions,
		"rewards": rewards,
		"old_log_probs": old_log_probs,
		"values": values,
		"dones": dones,
		"gamma": _gamma,
		"epsilon_clip": _epsilon_clip,
		"gae_lambda": _gae_lambda,
		"update_epochs": _update_epochs,
		"mini_batch_size": _mini_batch_size
	}

	var response = _send_command(cmd)
	if response.get("status") == "ok":
		_last_loss = response.get("loss", 0.0)
		_policy_entropy = response.get("entropy", 0.0)
		_mean_reward = response.get("mean_reward", 0.0)
		_total_steps += observations.size()
		training_step.emit(_last_loss)

		if response.get("done", false):
			_episode_count += 1
			episode_complete.emit(_mean_reward)

	return {
		"loss": _last_loss,
		"entropy": _policy_entropy,
		"mean_reward": _mean_reward,
		"done": response.get("done", false)
	}


func get_action_ppo(observations: Array, deterministic: bool = false) -> Dictionary:
	if not _initialized:
		return {"action": 0, "log_prob": 0.0, "value": 0.0}

	var cmd = {
		"cmd": "ppo_get_action",
		"observations": observations,
		"deterministic": deterministic
	}

	var response = _send_command(cmd)
	if response.get("status") == "ok":
		return {
			"action": response.get("action", 0),
			"log_prob": response.get("log_prob", 0.0),
			"value": response.get("value", 0.0)
		}
	return {"action": 0, "log_prob": 0.0, "value": 0.0}


func evaluate_actions(observations: Array, actions: Array) -> Dictionary:
	if not _initialized:
		return {"log_prob": 0.0, "entropy": 0.0, "value": 0.0}

	var cmd = {
		"cmd": "ppo_evaluate",
		"observations": observations,
		"actions": actions
	}

	var response = _send_command(cmd)
	if response.get("status") == "ok":
		return {
			"log_prob": response.get("log_prob", 0.0),
			"entropy": response.get("entropy", 0.0),
			"value": response.get("value", 0.0)
		}
	return {"log_prob": 0.0, "entropy": 0.0, "value": 0.0}


func _send_command(cmd: Dictionary) -> Dictionary:
	if not _bridge or not _bridge.is_bridge_connected():
		return {"status": "error", "message": "Bridge not connected"}
	return _bridge.send(cmd)
func save_model(path: String) -> bool:
	if not _initialized:
		return false

	var cmd = {"cmd": "ppo_save", "path": path}
	var response = _send_command(cmd)
	return response.get("status") == "ok"


func load_model(path: String) -> bool:
	if not _initialized:
		return false

	var cmd = {"cmd": "ppo_load", "path": path}
	var response = _send_command(cmd)
	return response.get("status") == "ok"


func get_model_info() -> Dictionary:
	return {
		"device": _device,
		"state_dim": _state_dim,
		"action_dim": _action_dim,
		"hidden_dim": _hidden_dim,
		"learning_rate": _learning_rate,
		"epsilon_clip": _epsilon_clip,
		"gae_lambda": _gae_lambda,
		"total_steps": _total_steps,
		"episode_count": _episode_count,
		"last_loss": _last_loss,
		"policy_entropy": _policy_entropy,
		"mean_reward": _mean_reward
	}