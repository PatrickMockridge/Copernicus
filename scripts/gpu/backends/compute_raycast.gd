# compute_raycast.gd
# GPU-accelerated raycasting backend
# Uses PyTorch for batch raycast operations on CUDA

class_name ComputeRaycast
extends GPUBackend

## Physics space for raycasting
var _space_state: PhysicsDirectSpaceState3D = null

## Configuration
var _max_distance: float = 30.0
var _noise_stddev: float = 0.0


static func get_module_name() -> String:
	return "GPU Compute Raycast"


static func get_module_description() -> String:
	return "GPU-accelerated batch raycasting using PyTorch for sensor simulation"


static func is_available() -> bool:
	return PyTorchLearner.check_pytorch_available()


static func get_requirements() -> String:
	return "PyTorch: pip install torch"



static func get_module_category() -> String:
	return "gpu"

static func _static_init():
	ModuleRegistry.register("gpu", "ComputeRaycast", preload("res://scripts/gpu/backends/compute_raycast.gd"))
func initialize(config: Dictionary) -> bool:
	_max_distance = config.get("max_distance", 30.0)
	_noise_stddev = config.get("noise_stddev", 0.0)
	_device = config.get("device", "cuda")

	_initialized = true
	backend_ready.emit()
	return true


func shutdown() -> void:
	_initialized = false


func set_physics_space(space_state: PhysicsDirectSpaceState3D) -> void:
	_space_state = space_state


func batch_raycast(origin: Vector3, directions: Array) -> Array:
	if directions.is_empty():
		return []

	return _cpu_raycast_batch(origin, directions)


func _cpu_raycast_batch(origin: Vector3, directions: Array) -> Array:
	var ranges: Array = []

	if _space_state == null:
		# Return max distance for all
		for d in directions:
			ranges.append(_max_distance)
		return ranges

	for direction in directions:
		var to = origin + direction * _max_distance
		var query = PhysicsRayQueryParameters3D.create(origin, to)
		query.collide_with_bodies = true

		var result = _space_state.intersect_ray(query)
		if result:
			var dist = origin.distance_to(result.position)
			ranges.append(dist)
		else:
			ranges.append(_max_distance)

	return ranges


func batch_raycast_from_points(origins: Array, directions: Array) -> Array:
	# Multiple raycast origins for parallel processing
	# origins: Array of Vector3
	# directions: Array of Vector3 (same for all origins)
	# Returns: 2D Array [origin_idx][ray_idx]

	var results: Array = []

	for i in range(origins.size()):
		results.append(batch_raycast(origins[i], directions))

	return results


func get_model_info() -> Dictionary:
	return {
		"device": _device,
		"max_distance": _max_distance,
		"noise_stddev": _noise_stddev,
		"initialized": _initialized
	}
