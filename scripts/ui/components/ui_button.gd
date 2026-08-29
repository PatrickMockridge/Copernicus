# ui_button.gd
# The atomic action. variant selects the stylebox family.

class_name UiButton
extends Button

enum Variant { PRIMARY, SECONDARY, GHOST, ICON }

var variant: Variant = Variant.SECONDARY


func setup(text: String, p_variant: Variant = Variant.SECONDARY) -> UiButton:
	self.text = text
	variant = p_variant
	_apply()
	return self


func _apply() -> void:
	var name := "button_secondary"
	match variant:
		Variant.PRIMARY: name = "button_primary"
		Variant.SECONDARY: name = "button_secondary"
		Variant.GHOST, Variant.ICON: name = "button_ghost"
	var sb := UiTheme.style(name)
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)
	add_theme_color_override("font_color", UiTheme.color("text"))
	add_theme_font_size_override("font_size", UiTheme.font_size("body"))
	if variant == Variant.GHOST or variant == Variant.ICON:
		flat = true
	if variant == Variant.ICON:
		add_theme_font_size_override("font_size", 18)
