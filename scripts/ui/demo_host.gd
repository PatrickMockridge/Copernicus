# demo_host.gd
# In-place host for standalone 3D demo scenes (physics/turtle). Embeds the scene
# in a SubViewport with a title bar + Back button, so it no longer swaps the window.

class_name DemoHost
extends Control

signal closed()

var _scene_path: String
var _title: String


func setup(scene_path: String, title: String) -> void:
	_scene_path = scene_path
	_title = title


func _ready() -> void:
	_build()


func _build() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("panel")
	sb.border_width_bottom = 1
	sb.border_color = UiTheme.color("border")
	bar.add_theme_stylebox_override("panel", sb)
	v.add_child(bar)

	var bar_h := HBoxContainer.new()
	bar_h.add_theme_constant_override("separation", UiTheme.space("s"))
	bar.add_child(bar_h)
	var title := UiLabel.new().setup(_title, UiLabel.Kind.HEADING, UiLabel.Tone.PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_h.add_child(title)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void:
		closed.emit()
		queue_free()
	)
	bar_h.add_child(back)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(vpc)

	var sub := SubViewport.new()
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.handle_input_locally = true
	vpc.add_child(sub)

	var scene = load(_scene_path).instantiate()
	sub.add_child(scene)
