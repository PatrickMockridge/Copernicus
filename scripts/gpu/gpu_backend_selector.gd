# gpu_backend_selector.gd
# UI for selecting which GPU acceleration backend to use

class_name GPUBackendSelector
extends BaseSelector

signal backend_selected(backend_class: String)

# Preload backends so their _static_init registers them with ModuleRegistry.
const PyTorchLearner = preload("res://scripts/gpu/backends/pytorch_learner.gd")
const ComputeRaycast = preload("res://scripts/gpu/backends/compute_raycast.gd")
const CUDAPhysics = preload("res://scripts/gpu/backends/cuda_physics.gd")


func _get_title() -> String:
	return "Select GPU Backend"


func _get_info_text() -> String:
	return "Enable GPU acceleration for physics, learning, and sensors. CUDA required for GPU backends."


func _get_button_group_name() -> String:
	return "gpu_backend"


func _get_category() -> String:
	return "gpu"


func _populate_options(container: VBoxContainer) -> void:
	super._populate_options(container)


func _on_apply_pressed() -> void:
	backend_selected.emit(_selected_id)
	queue_free()


static func create_backend(backend_id: String, config: Dictionary = {}) -> GPUBackend:
	return ModuleRegistry.create("gpu", backend_id, config)
