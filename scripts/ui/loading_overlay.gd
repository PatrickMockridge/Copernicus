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
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -120
	panel.offset_top = -40
	panel.offset_right = 120
	panel.offset_bottom = 40

	panel.add_theme_stylebox_override("panel", UiTheme.style("panel"))
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var label = UiLabel.new().setup(message, UiLabel.Kind.HEADING, UiLabel.Tone.PRIMARY)
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
