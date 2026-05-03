# cuda_physics.gd
# PyBullet CUDA physics backend
# GPU-accelerated physics using PyBullet with CUDA support

class_name CUDAPhysics
extends GPUBackend

const PyBulletBackend = preload("res://scripts/physics/pybullet_backend.gd")

## PyBullet instance
var _physics: PyBulletBackend

## CUDA state
var _cuda_available: bool = false
var _use_cuda: bool = true


static func get_backend_name() -> String:
	return "PyBullet CUDA"


static func get_backend_description() -> String:
	return "GPU-accelerated physics via PyBullet with CUDA support"


static func is_available() -> bool:
	# Check if PyBullet CUDA is available
	var output = []; var result = OS.execute("python3", ["-c", "import pybullet; print(hasattr(pybullet, 'CUDA'))"], output, true)
	if result == 0 and output.size() > 0:
		return "True" in output[0] or "1" in output[0]
	return false


static func get_requirements() -> String:
	return "PyBullet with CUDA support: pip install pybullet torch"


func initialize(config: Dictionary) -> bool:
	_use_cuda = config.get("use_cuda", true)

	# Create PyBullet backend
	_physics = PyBulletBackend.new()
	if not _physics.initialize(config):
		backend_error.emit("Failed to initialize PyBullet")
		return false

	# Check CUDA availability
	if _use_cuda:
		_cuda_available = _check_cuda_connection()
		if not _cuda_available:
			push_warning("CUDAPhysics: CUDA not available, falling back to CPU")
			_use_cuda = false

	_initialized = true
	backend_ready.emit()
	return true


func _check_cuda_connection() -> bool:
	# PyBullet uses CUDA when you call setGravity with a GPU-enabled client
	# We can verify by checking the physics engine
	var output = []; var result = OS.execute("python3", ["-c", """
import pybullet as p
import pybullet_data
cid = p.connect(p.GUI)
info = p.getPhysicsInfo(cid)
print('cuda' if info.gpuEnabled else 'cpu')
p.disconnect(cid)
"""], output, true)
	if result == 0 and output.size() > 0 and "cuda" in output[0].to_lower():
		return true
	return false


func shutdown() -> void:
	if _physics:
		_physics.shutdown()
	_initialized = false


func step_simulation(delta: float) -> void:
	if _physics:
		_physics.step_simulation(delta)


func apply_force(body_name: String, link_index: int, force: Vector3, position: Vector3) -> void:
	if _physics:
		_physics.apply_force(body_name, link_index, force, position)


func get_body_state(body_name: String) -> Dictionary:
	if _physics:
		return _physics.get_body_state(body_name)
	return {}


func get_device() -> String:
	if _use_cuda and _cuda_available:
		return "cuda"
	return "cpu"


func get_model_info() -> Dictionary:
	return {
		"device": get_device(),
		"initialized": _initialized,
		"cuda_available": _cuda_available,
		"physics": "pybullet"
	}
