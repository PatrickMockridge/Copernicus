class_name RaasLauncher
extends Control
## In-place launcher for the robotics-as-a-service demos. Emits `demo_requested`
## with the demo scene path; the shell opens it as an overlay in the editor.

signal demo_requested(scene_path: String)


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	var win := UiPanel.new().setup("RaaS Demos")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)

	var v: VBoxContainer = win.body()

	v.add_child(UiLabel.new().setup(
		"Choose a robot. Each demo shows the RaaS flow: fund a job on-chain, execute it, and settle a work-metered fee (work × rate).",
		UiLabel.Kind.BODY, UiLabel.Tone.MUTED
	))
	v.add_child(UiSeparator.new())

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
	var card := UiPanel.new().setup("")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.space("m"))
	card.body().add_child(h)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	text.add_child(UiLabel.new().setup(title, UiLabel.Kind.HEADING, UiLabel.Tone.PRIMARY))
	text.add_child(UiLabel.new().setup(description, UiLabel.Kind.BODY, UiLabel.Tone.MUTED))

	var open := UiButton.new().setup("Open", UiButton.Variant.SECONDARY)
	open.pressed.connect(func() -> void: demo_requested.emit(scene_path))
	h.add_child(open)

	return card
