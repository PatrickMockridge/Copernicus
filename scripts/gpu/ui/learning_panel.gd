# learning_panel.gd
# Reinforcement learning training panel
# Provides UI for training robots with PyTorch DQN

class_name LearningPanel
extends Control

## PyTorch learner backend
var _learner: RefCounted = null

## Training state
var _is_training: bool = false
var _episode_count: int = 0
var _total_steps: int = 0
var _last_loss: float = 0.0
var _epsilon: float = 1.0

## UI references
var _status_label: Label
var _episode_label: Label
var _steps_label: Label
var _loss_label: Label
var _epsilon_slider: HSlider
var _epsilon_value: Label
var _start_btn: Button
var _stop_btn: Button
var _save_btn: Button


func _ready() -> void:
	_setup_ui()
	_initialize_learner()


func _setup_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "PyTorch Q-Learning"
	header.add_theme_font_size_override("font_size", 20)
	vbox.add_child(header)

	var desc = Label.new()
	desc.text = "Train robot policies using Deep Q-Networks (DQN) with experience replay."
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Stats grid
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(stats_grid)

	_stats_row(stats_grid, "Status:", "Idle")
	_stats_row(stats_grid, "Episodes:", "0")
	_stats_row(stats_grid, "Total Steps:", "0")
	_stats_row(stats_grid, "Last Loss:", "0.000")
	_stats_row(stats_grid, "Epsilon:", "1.000")

	# Separator 2
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Epsilon slider
	var eps_container = HBoxContainer.new()
	vbox.add_child(eps_container)

	var eps_label = Label.new()
	eps_label.text = "Exploration (ε):"
	eps_label.custom_minimum_size.x = 120
	eps_container.add_child(eps_label)

	_epsilon_slider = HSlider.new()
	_epsilon_slider.min_value = 0.01
	_epsilon_slider.max_value = 1.0
	_epsilon_slider.step = 0.01
	_epsilon_slider.value = 1.0
	_epsilon_slider.custom_minimum_size.x = 150
	_epsilon_slider.value_changed.connect(_on_epsilon_changed)
	eps_container.add_child(_epsilon_slider)

	_epsilon_value = Label.new()
	_epsilon_value.text = "1.00"
	_epsilon_value.custom_minimum_size.x = 50
	_epsilon_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	eps_container.add_child(_epsilon_value)

	# Buttons
	var btn_container = HBoxContainer.new()
	vbox.add_child(btn_container)

	_start_btn = Button.new()
	_start_btn.text = "Start Training"
	_start_btn.pressed.connect(_on_start_training)
	btn_container.add_child(_start_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.disabled = true
	_stop_btn.pressed.connect(_on_stop_training)
	btn_container.add_child(_stop_btn)

	var spacer = Control.new()
	spacer.custom_minimum_size.x = 20
	btn_container.add_child(spacer)

	_save_btn = Button.new()
	_save_btn.text = "Save Model"
	_save_btn.pressed.connect(_on_save_model)
	btn_container.add_child(_save_btn)

	# Info
	var info = Label.new()
	info.text = "Uses PyTorch DQN with epsilon-greedy exploration. Observations and rewards are sent to the Python subprocess for GPU-accelerated training."
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)


func _stats_row(grid: GridContainer, label_text: String, value: String) -> void:
	var label = Label.new()
	label.text = label_text
	grid.add_child(label)

	var value_label = Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.name = label_text.replace(":", "")
	grid.add_child(value_label)


func _initialize_learner() -> void:
	_learner = PyTorchLearner.new()
	var config = {
		"state_dim": 24,
		"action_dim": 4,
		"hidden_dim": 128,
		"device": "cuda" if GPUBackend.check_cuda_available() else "cpu"
	}
	if _learner.initialize(config):
		_update_status("Ready")
	else:
		_update_status("Init Failed")


func _update_status(status: String) -> void:
	if _status_label:
		_status_label.text = status


func _on_epsilon_changed(value: float) -> void:
	_epsilon = value
	_epsilon_value.text = "%.2f" % value
	if _learner:
		_learner.set_epsilon(value)


func _on_start_training() -> void:
	_is_training = true
	_start_btn.disabled = true
	_stop_btn.disabled = false
	_update_status("Training...")


func _on_stop_training() -> void:
	_is_training = false
	_start_btn.disabled = false
	_stop_btn.disabled = true
	_update_status("Paused")


func _on_save_model() -> void:
	if _learner and _learner.save_model("learned_policy.pt"):
		_update_status("Model saved")
	else:
		_update_status("Save failed")


func get_learner() -> RefCounted:
	return _learner


func is_training() -> bool:
	return _is_training


func train_step(observations: Array, actions: Array, rewards: Array) -> Dictionary:
	if _learner and _is_training:
		var result = _learner.train_step(observations, actions, rewards)
		_last_loss = result.get("loss", 0.0)
		return result
	return {"loss": 0.0, "done": false}