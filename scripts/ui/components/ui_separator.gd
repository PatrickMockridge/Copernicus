# ui_separator.gd
# A 1px horizontal separator.

class_name UiSeparator
extends HSeparator


func _init() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.color("border")
	add_theme_stylebox_override("separator", sb)
