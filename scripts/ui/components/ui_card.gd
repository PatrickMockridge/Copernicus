# ui_card.gd
# A selectable card (robot, listing, manual section). Button with a swatch +
# title + subtitle.

class_name UiCard
extends Button

var _title: UiLabel


func setup(title: String, subtitle: String = "", swatch: Color = Color.TRANSPARENT, enabled: bool = true) -> UiCard:
	var sb := UiTheme.style("card")
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)
	disabled = not enabled
	custom_minimum_size = Vector2(180, 110)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", UiTheme.space("xs"))
	add_child(v)
	if swatch.a > 0.0:
		var rect := ColorRect.new()
		rect.color = swatch
		rect.custom_minimum_size.y = 40
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(rect)
	_title = UiLabel.new().setup(title, UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)
	if not subtitle.is_empty():
		var sub := UiLabel.new().setup(subtitle, UiLabel.Kind.SMALL, UiLabel.Tone.MUTED)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sub)
	return self


func set_title(t: String) -> void:
	if _title:
		_title.text = t
