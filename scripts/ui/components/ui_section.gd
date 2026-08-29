# ui_section.gd
# A small uppercase section header inside a panel body.

class_name UiSection
extends Label


func setup(text: String) -> UiSection:
	self.text = text.to_upper()
	add_theme_font_size_override("font_size", UiTheme.font_size("small"))
	add_theme_color_override("font_color", UiTheme.color("text_muted"))
	return self
