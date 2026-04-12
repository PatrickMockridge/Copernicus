# gpu_backend.gd
# Abstract GPU backend interface
# All GPU acceleration backends must implement this

class_name GPUBackend
extends RefCounted

## Signals

signal backend_ready()
signal backend_error(message: String)
signal training_step(loss: float)
signal episode_complete(reward: float)
signal inference_complete(action: int)
signal raycast_complete(ranges: Array)


## ===== Configuration =====

var _device: String = "cuda"  # "cuda" or "cpu"
var _initialized: bool = false


## ===== Core Methods =====

static func get_backend_name() -> String:
	return "Unknown GPU Backend"


static func get_backend_description() -> String:
	return ""


static func is_available() -> bool:
	return false


func initialize(config: Dictionary) -> bool:
	_device = config.get("device", "cuda")
	_initialized = true
	backend_ready.emit()
	return true


func shutdown() -> void:
	_initialized = false


func is_initialized() -> bool:
	return _initialized


func get_device() -> String:
	return _device


## ===== Physics Methods =====

func step_simulation(delta: float) -> void:
	pass


func apply_force(body_name: String, link_index: int, force: Vector3, position: Vector3) -> void:
	pass


func get_body_state(body_name: String) -> Dictionary:
	return {}


## ===== Learning Methods =====

func train_step(observations: Array, actions: Array, rewards: Array) -> Dictionary:
	# observations: Array of state vectors
	# actions: Array of action indices
	# rewards: Array of reward floats
	# Returns {loss: float, done: bool}
	return {"loss": 0.0, "done": false}


func get_action(observations: Array) -> int:
	# Epsilon-greedy action from Q-network
	# Returns action index
	return 0


func set_learning_rate(lr: float) -> void:
	pass


func set_epsilon(eps: float) -> void:
	pass


func get_epsilon() -> float:
	return 0.1


func save_model(path: String) -> bool:
	return true


func load_model(path: String) -> bool:
	return true


func get_model_info() -> Dictionary:
	return {
		"device": _device,
		"initialized": _initialized
	}


## ===== Sensor Acceleration Methods =====

func batch_raycast(origin: Vector3, directions: Array) -> Array:
	# GPU-accelerated raycast for LIDAR/camera
	# directions: Array of Vector3 normalized directions
	# Returns: Array of floats (ranges for each direction)
	return []


func batch_raycast_from_points(origins: Array, directions: Array) -> Array:
	# Multiple raycast origins for parallel processing
	return []


## ===== Static Helpers =====

static func check_cuda_available() -> bool:
	var result = OS.execute("python3", ["-c", "import torch; print(torch.cuda.is_available())"], true)
	return result[0] == 0 and "True" in result[1]


static func check_pytorch_available() -> bool:
	var result = OS.execute("python3", ["-c", "import torch; print('ok')"], true)
	return result[0] == 0


static func check_pybullet_cuda_available() -> bool:
	var result = OS.execute("python3", ["-c", "import pybullet; print(hasattr(pybullet, 'CUDA'))"], true)
	if result[0] == 0:
		return "True" in result[1] or "1" in result[1]
	return false


static func format_tensor_info(tensor) -> String:
	if tensor.is_cuda:
		return "CUDA tensor shape=%s device=%s" % [str(tensor.shape), tensor.device]
	return "CPU tensor shape=%s" % str(tensor.shape)
