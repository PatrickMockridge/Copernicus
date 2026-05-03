# gpu_backend_selector.gd
# UI for selecting which GPU acceleration backend to use

class_name GPUBackendSelector
extends BaseSelector

signal backend_selected(backend_class: String)


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
	_add_option("IsaacGymTask", "Isaac Gym RL", "NVIDIA Isaac Gym multi-robot RL training. GPU-accelerated with 4096 parallel environments.", false)
	_add_option("MultiRobotTrainer", "Multi-Robot Trainer", "Distributed multi-robot training coordinator. Supports PPO, SAC, and TD3 algorithms.", true)


func _on_apply_pressed() -> void:
	backend_selected.emit(_selected_id)
	queue_free()


static func create_backend(backend_id: String, config: Dictionary = {}) -> GPUBackend:
	return ModuleRegistry.create("gpu", backend_id, config)
