# loading_overlay.gd
# Full-screen overlay with spinner text during long operations

class_name LoadingOverlay
extends CanvasLayer


static func show_overlay(parent: Node, message: String = "Loading..."):
	var overlay = load("res://scripts/ui/loading_overlay.gd").new()
	overlay._build(message)
	parent.add_child(overlay)
	return overlay


func _build(message: String) -> void:
	var bg = ColorRect.new()
	bg.color = UiTheme.color("backdrop")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.style("panel"))
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UiTheme.space("s"))
	panel.add_child(vbox)

	var label = UiLabel.new().setup(message, UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 220
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var dots = Label.new()
	dots.text = "..."
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_font_size_override("font_size", 20)
	dots.add_theme_color_override("font_color", UiTheme.color("text_muted"))
	vbox.add_child(dots)

	# Animate dots
	var tween = create_tween()
	tween.set_loops()
	tween.tween_interval(0.4)
	tween.tween_callback(func(): dots.text = ".." if dots.text == "..." else ("..." if dots.text == "." else "."))


func dismiss() -> void:
	queue_free()
