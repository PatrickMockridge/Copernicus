class_name RaasLauncher
extends Control
## Launcher for the robotics-as-a-service demos. Lists the available robots; each
## card opens its own demo scene.

func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_theme_constant_override("separation", 12)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	v.add_child(back)

	v.add_child(CopernicusTheme.make_heading("Robotics-as-a-Service Demos"))
	v.add_child(CopernicusTheme.make_body(
		"Choose a robot. Each demo shows the RaaS flow: fund a job on-chain, execute it, and settle a work-metered fee (work × rate)."
	))
	v.add_child(CopernicusTheme.make_separator())

	v.add_child(_make_card(
		"TurtleBot — Drive",
		"A wheeled robot drives when a chain job is funded; the fee scales with distance.",
		"res://scenes/rchain/raas_demo_turtlebot.tscn"
	))
	v.add_child(_make_card(
		"Kuka KR210 — Pick-and-Place",
		"A 6-DOF arm performs pick-and-place when a chain job is funded; the fee scales with joint travel.",
		"res://scenes/rchain/raas_demo_kuka.tscn"
	))


func _make_card(title: String, description: String, scene_path: String) -> Control:
	var card := PanelContainer.new()
	CopernicusTheme.style_card(card)

	var h := HBoxContainer.new()
	card.add_child(h)
	h.add_theme_constant_override("separation", 12)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	text.add_child(CopernicusTheme.make_heading(title))
	text.add_child(CopernicusTheme.make_body(description))

	var open := Button.new()
	open.text = "Open"
	open.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene_path))
	h.add_child(open)

	return card
