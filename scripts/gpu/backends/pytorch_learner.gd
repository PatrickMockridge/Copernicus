# pytorch_learner.gd
# PyTorch Q-learning backend
# Deep reinforcement learning using PyTorch with CUDA support

class_name PyTorchLearner
extends GPUBackend

## Neural network configuration
var _state_dim: int = 0
var _bridge: PythonBridge
var _action_dim: int = 0
var _hidden_dim: int = 128
var _learning_rate: float = 0.001
var _gamma: float = 0.99  # Discount factor
var _epsilon: float = 1.0  # Exploration rate
var _epsilon_min: float = 0.01
var _epsilon_decay: float = 0.995

## Training state
var _total_steps: int = 0
var _episode_count: int = 0
var _last_loss: float = 0.0

## Python subprocess communication
var _python_process: int = -1


static func get_module_name() -> String:
	return "PyTorch Q-Learning"


static func get_module_description() -> String:
	return "Deep Q-network (DQN) reinforcement learning via PyTorch with CUDA"


static func is_available() -> bool:
	var output = []; var result = OS.execute("python3", ["-c", "import torch; print(torch.__version__)"], output, true)
	return result == 0


static func get_requirements() -> String:
	return "PyTorch: pip install torch"


static func check_cuda_available() -> bool:
	var result = OS.execute("nvidia-smi", [], [], true)
	return result == OK



static func get_module_category() -> String:
	return "gpu"

static func _static_init():
	ModuleRegistry.register("gpu", "PyTorchLearner", preload("res://scripts/gpu/backends/pytorch_learner.gd"))
func initialize(config: Dictionary) -> bool:
	_state_dim = config.get("state_dim", 24)
	_action_dim = config.get("action_dim", 4)
	_hidden_dim = config.get("hidden_dim", 128)
	_learning_rate = config.get("learning_rate", 0.001)
	_gamma = config.get("gamma", 0.99)
	_device = config.get("device", "cuda" if check_cuda_available() else "cpu")

	_bridge = PythonBridge.new()
	var script_path = ProjectSettings.globalize_path("res://scripts/gpu/pytorch_learning_node.py")
	if not _bridge.start(script_path, 9877):
		push_error("PyTorchLearner: Failed to start Python bridge")
		return false

	if _python_process < 0:
		push_error("PyTorchLearner: Failed to start Python node")
		return false



	# Send init command
	var init_result = _send_command({
		"cmd": "init",
		"state_dim": _state_dim,
		"action_dim": _action_dim,
		"hidden_dim": _hidden_dim,
		"device": _device
	})

	if init_result.get("status") != "ok":
		push_error("PyTorchLearner: Init failed: " + init_result.get("message", "unknown"))
		return false

	_initialized = true
	backend_ready.emit()
	return true


func shutdown() -> void:
	if _bridge:
		_bridge.shutdown()
		_bridge = null
	_initialized = false

func train_step(observations: Array, actions: Array, rewards: Array) -> Dictionary:
	if observations.is_empty() or not _initialized:
		return {"loss": 0.0, "done": false}

	# Build JSON command
	var cmd = {
		"cmd": "train_step",
		"observations": observations,
		"actions": actions,
		"rewards": rewards,
		"gamma": _gamma,
		"lr": _learning_rate
	}

	var response = _send_command(cmd)
	if response.get("status") == "ok":
		_last_loss = response.get("loss", 0.0)
		_total_steps += observations.size()
		training_step.emit(_last_loss)

		if response.get("done", false):
			_episode_count += 1
			var total_reward = response.get("episode_reward", 0.0)
			episode_complete.emit(total_reward)
			_decay_epsilon()

	return {"loss": _last_loss, "done": response.get("done", false)}


func get_action(observations: Array) -> int:
	if not _initialized:
		return 0

	# Epsilon-greedy action
	if randf() < _epsilon:
		return randi() % _action_dim

	var cmd = {
		"cmd": "get_action",
		"observations": observations
	}

	var response = _send_command(cmd)
	if response.get("status") == "ok":
		return response.get("action", 0)
	return 0


func _decay_epsilon() -> void:
	_epsilon = max(_epsilon_min, _epsilon * _epsilon_decay)


func _send_command(cmd: Dictionary) -> Dictionary:
	if not _bridge or not _bridge.is_bridge_connected():
		return {"status": "error", "message": "Bridge not connected"}
	return _bridge.send(cmd)

func set_learning_rate(lr: float) -> void:
	_learning_rate = lr


func set_epsilon(eps: float) -> void:
	_epsilon = eps


func get_epsilon() -> float:
	return _epsilon


func save_model(path: String) -> bool:
	if not _initialized:
		return false

	var cmd = {"cmd": "save_model", "path": path}
	var response = _send_command(cmd)
	return response.get("status") == "ok"


func load_model(path: String) -> bool:
	if not _initialized:
		return false

	var cmd = {"cmd": "load_model", "path": path}
	var response = _send_command(cmd)
	return response.get("status") == "ok"


func get_model_info() -> Dictionary:
	return {
		"device": _device,
		"state_dim": _state_dim,
		"action_dim": _action_dim,
		"hidden_dim": _hidden_dim,
		"learning_rate": _learning_rate,
		"epsilon": _epsilon,
		"total_steps": _total_steps,
		"episode_count": _episode_count,
		"last_loss": _last_loss
	}
