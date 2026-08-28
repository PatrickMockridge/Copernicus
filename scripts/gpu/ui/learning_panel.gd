# learning_panel.gd
# Reinforcement learning training panel
# Provides UI for training robots with PyTorch DQN/PPO/SAC

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
var _mean_reward: float = 0.0
var _policy_entropy: float = 0.0

## Metrics history for charts
var _reward_history: Array = []
var _loss_history: Array = []
var _entropy_history: Array = []
var _max_history: int = 500

## UI references
var _status_value: Label
var _episode_value: Label
var _steps_value: Label
var _loss_value: Label
var _epsilon_value: Label
var _reward_value: Label
var _entropy_value: Label
var _epsilon_slider: HSlider
var _start_btn: Button
var _stop_btn: Button
var _save_btn: Button
var _chart_texture: TextureRect


func _ready() -> void:
	_setup_ui()
	_initialize_learner()


func _setup_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Header
	vbox.add_child(CopernicusTheme.make_heading("PyTorch RL Training"))

	var desc = Label.new()
	desc.text = "Train robot policies using DQN, PPO, or SAC with GPU acceleration."
	desc.add_theme_color_override("font_color", CopernicusTheme.TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Stats grid
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 30)
	stats_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(stats_grid)

	_stats_row(stats_grid, "Status:", "Idle", "status")
	_stats_row(stats_grid, "Episode:", "0", "episode")
	_stats_row(stats_grid, "Steps:", "0", "steps")
	_stats_row(stats_grid, "Loss:", "0.000", "loss")
	_stats_row(stats_grid, "Reward:", "0.00", "reward")
	_stats_row(stats_grid, "Entropy:", "0.00", "entropy")
	_stats_row(stats_grid, "Epsilon:", "1.00", "epsilon")

	# Chart area (placeholder - would need shader or Line2D for actual chart)
	var chart_container = PanelContainer.new()
	chart_container.custom_minimum_size.y = 120
	CopernicusTheme.style_card(chart_container)
	vbox.add_child(chart_container)

	var chart_label = Label.new()
	chart_label.text = "Episode Reward History"
	chart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chart_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chart_container.add_child(chart_label)

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
	info.text = "Supports DQN, PPO, and SAC algorithms. Metrics tracked for episode reward, loss, and policy entropy."
	info.add_theme_color_override("font_color", CopernicusTheme.TEXT_DISABLED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)


func _stats_row(grid: GridContainer, label_text: String, value: String, value_name: String) -> void:
	var label = Label.new()
	label.text = label_text
	grid.add_child(label)

	var value_label = Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.name = "Value_" + value_name
	grid.add_child(value_label)

	# Store reference based on value_name
	match value_name:
		"status": _status_value = value_label
		"episode": _episode_value = value_label
		"steps": _steps_value = value_label
		"loss": _loss_value = value_label
		"reward": _reward_value = value_label
		"entropy": _entropy_value = value_label
		"epsilon": _epsilon_value = value_label


func _initialize_learner() -> void:
	_learner = PyTorchLearner.new()
	var config = {
		"state_dim": 24,
		"action_dim": 4,
		"hidden_dim": 128,
		"device": "cuda" if GPUBackend.check_pytorch_available() else "cpu"
	}
	if _learner.initialize(config):
		_update_label(_status_value, "Ready")
	else:
		_update_label(_status_value, "Init Failed")


func _update_label(label: Label, text: String) -> void:
	if label:
		label.text = text


func _on_epsilon_changed(value: float) -> void:
	_epsilon = value
	_update_label(_epsilon_value, "%.2f" % value)
	if _learner:
		_learner.set_epsilon(value)


func _on_start_training() -> void:
	_is_training = true
	_start_btn.disabled = true
	_stop_btn.disabled = false
	_update_label(_status_value, "Training...")


func _on_stop_training() -> void:
	_is_training = false
	_start_btn.disabled = false
	_stop_btn.disabled = true
	_update_label(_status_value, "Paused")


func _on_save_model() -> void:
	if _learner and _learner.save_model("learned_policy.pt"):
		_update_label(_status_value, "Model saved")
	else:
		_update_label(_status_value, "Save failed")


func get_learner() -> RefCounted:
	return _learner


func is_training() -> bool:
	return _is_training


func train_step(observations: Array, actions: Array, rewards: Array) -> Dictionary:
	if _learner and _is_training:
		var result = _learner.train_step(observations, actions, rewards)
		_last_loss = result.get("loss", 0.0)

		# Update metrics history
		var reward = result.get("episode_reward", result.get("mean_reward", 0.0))
		if reward != 0.0:
			_reward_history.append(reward)
			if _reward_history.size() > _max_history:
				_reward_history.pop_front()

		_loss_history.append(_last_loss)
		if _loss_history.size() > _max_history:
			_loss_history.pop_front()

		# Update UI
		_update_label(_loss_value, "%.4f" % _last_loss)
		_update_label(_reward_value, "%.2f" % reward)
		_update_label(_steps_value, str(_total_steps))

		return result
	return {"loss": 0.0, "done": false}


func record_episode(reward: float, episode: int) -> void:
	_episode_count = episode
	_mean_reward = reward

	# Add to history
	_reward_history.append(reward)
	if _reward_history.size() > _max_history:
		_reward_history.pop_front()

	# Update UI
	_update_label(_episode_value, str(_episode_count))
	_update_label(_reward_value, "%.2f" % reward)


func record_metric(name: String, value: float) -> void:
	match name:
		"loss":
			_last_loss = value
			_loss_history.append(value)
			if _loss_history.size() > _max_history:
				_loss_history.pop_front()
			_update_label(_loss_value, "%.4f" % value)
		"entropy":
			_policy_entropy = value
			_entropy_history.append(value)
			if _entropy_history.size() > _max_history:
				_entropy_history.pop_front()
			_update_label(_entropy_value, "%.3f" % value)
		"steps":
			_total_steps = int(value)
			_update_label(_steps_value, str(_total_steps))


func get_metrics() -> Dictionary:
	return {
		"reward_history": _reward_history.duplicate(),
		"loss_history": _loss_history.duplicate(),
		"entropy_history": _entropy_history.duplicate(),
		"episode_count": _episode_count,
		"total_steps": _total_steps,
		"last_loss": _last_loss,
		"mean_reward": _mean_reward,
		"policy_entropy": _policy_entropy
	}