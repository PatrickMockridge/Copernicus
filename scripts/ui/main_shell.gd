# main_shell.gd
# App shell: left sidebar navigation + a content host that swaps panels in place.
# This is the main scene. The 3D robot workspace (Viewer) is the default panel.

class_name MainShell
extends Control

const CompositeWorkspace = preload("res://scripts/composite_workspace.gd")
const AiAssistantPanel = preload("res://scripts/main.gd")
const MarketplacePanel = preload("res://scripts/marketplace/ui/marketplace_panel.gd")
const WalletPanel = preload("res://scripts/rchain/ui/wallet_panel.gd")
const CoordinationPanel = preload("res://scripts/rchain/ui/coordination_panel.gd")

var _content_host: Control
var _nav_buttons: Dictionary = {}
var _panels: Dictionary = {}


func _ready() -> void:
	_setup_ui()
	_setup_panels()
	_select("viewer")


func _setup_ui() -> void:
	var root = HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ---- Sidebar ----
	var sidebar = PanelContainer.new()
	sidebar.custom_minimum_size.x = 200
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	CopernicusTheme.style_panel(sidebar)
	root.add_child(sidebar)

	var nav = VBoxContainer.new()
	nav.add_theme_constant_override("separation", CopernicusTheme.SPACE_XS)
	sidebar.add_child(nav)

	var brand = CopernicusTheme.make_heading("Copernicus")
	nav.add_child(brand)
	nav.add_child(CopernicusTheme.make_separator())

	for item in [
		["viewer", "Viewer"],
		["ai", "AI Assistant"],
		["marketplace", "Marketplace"],
		["wallet", "Wallet"],
		["coordination", "Coordination"],
	]:
		var btn = CopernicusTheme.make_nav_item(item[1], item[0])
		btn.pressed.connect(_on_nav_pressed.bind(item[0]))
		nav.add_child(btn)
		_nav_buttons[item[0]] = btn

	var raas_btn = CopernicusTheme.make_nav_item("RaaS Demos", "raas")
	raas_btn.pressed.connect(_open_raas)
	nav.add_child(raas_btn)

	# ---- Content host ----
	_content_host = Control.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content_host)


func _setup_panels() -> void:
	var viewer = CompositeWorkspace.new()
	_add_panel("viewer", viewer)
	var robot_viewer = viewer.get_robot_viewer()

	var ai = AiAssistantPanel.new()
	_add_panel("ai", ai)
	if robot_viewer:
		ai.set_viewer(robot_viewer)

	var marketplace = MarketplacePanel.new()
	_add_panel("marketplace", marketplace)
	marketplace.closed.connect(func() -> void: _select("viewer"))

	_add_panel("wallet", WalletPanel.new())
	_add_panel("coordination", CoordinationPanel.new())


func _add_panel(id: String, panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_host.add_child(panel)
	panel.visible = false
	_panels[id] = panel


func _select(id: String) -> void:
	for key in _panels:
		_panels[key].visible = (key == id)
	for key in _nav_buttons:
		CopernicusTheme.set_nav_active(_nav_buttons[key], key == id)


func _on_nav_pressed(id: String) -> void:
	_select(id)


func _open_raas() -> void:
	get_tree().change_scene_to_file("res://scenes/rchain/raas_launcher.tscn")
