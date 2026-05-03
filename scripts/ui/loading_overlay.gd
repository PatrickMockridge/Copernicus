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

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.25, 0.3, 1)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(label)

	var dots = Label.new()
	dots.text = "..."
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_font_size_override("font_size", 20)
	dots.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(dots)

	# Animate dots
	var tween = create_tween()
	tween.set_loops()
	tween.tween_interval(0.4)
	tween.tween_callback(func(): dots.text = ".." if dots.text == "..." else ("..." if dots.text == "." else "."))


func dismiss() -> void:
	queue_free()
