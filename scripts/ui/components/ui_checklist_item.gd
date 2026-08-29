# ui_checklist_item.gd
# One validation criterion rendered as pass/fail.

class_name UiChecklistItem
extends HBoxContainer


func setup(label: String, ok: bool, actual: String = "", expect: String = "") -> UiChecklistItem:
	add_theme_constant_override("separation", UiTheme.space("s"))
	add_child(UiLabel.new().setup("✓" if ok else "✗", UiLabel.Kind.SMALL, UiLabel.Tone.SUCCESS if ok else UiLabel.Tone.ERROR))
	var lbl := UiLabel.new().setup(label, UiLabel.Kind.SMALL, UiLabel.Tone.PRIMARY)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(lbl)
	if not actual.is_empty() or not expect.is_empty():
		add_child(UiLabel.new().setup("%s / %s" % [actual, expect], UiLabel.Kind.SMALL, UiLabel.Tone.MUTED))
	return self
