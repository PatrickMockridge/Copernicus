# ui_label.gd
# The atomic text readout. kind = font/size, tone = color.

class_name UiLabel
extends Label

enum Kind { TITLE, HEADING, BODY, SMALL, MONO }
enum Tone { PRIMARY, MUTED, FAINT, ACCENT, SUCCESS, WARNING, ERROR }

var kind: Kind = Kind.BODY
var tone: Tone = Tone.PRIMARY


func setup(text: String, p_kind: Kind = Kind.BODY, p_tone: Tone = Tone.PRIMARY) -> UiLabel:
	self.text = text
	kind = p_kind
	tone = p_tone
	_apply()
	return self


func _apply() -> void:
	var fname := "ui"
	var fsize := "body"
	match kind:
		Kind.TITLE: fname = "display"; fsize = "title"
		Kind.HEADING: fname = "display"; fsize = "heading"
		Kind.BODY: fname = "ui"; fsize = "body"
		Kind.SMALL: fname = "ui"; fsize = "small"
		Kind.MONO: fname = "mono"; fsize = "body"
	add_theme_font_size_override("font_size", UiTheme.font_size(fsize))
	if UiTheme.font(fname):
		add_theme_font_override("font", UiTheme.font(fname))
	var cname := "text"
	match tone:
		Tone.MUTED: cname = "text_muted"
		Tone.FAINT: cname = "text_faint"
		Tone.ACCENT: cname = "accent"
		Tone.SUCCESS: cname = "success"
		Tone.WARNING: cname = "warning"
		Tone.ERROR: cname = "error"
	add_theme_color_override("font_color", UiTheme.color(cname))
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if kind == Kind.BODY else TextServer.AUTOWRAP_OFF
