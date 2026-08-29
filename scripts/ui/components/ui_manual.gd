# ui_manual.gd
# The in-app rulebook: a list of docs/ on the left, the selected doc on the right.

class_name UiManual
extends UiPanel

var _list: UiScrollList
var _view: TextEdit


func configure() -> UiManual:
	setup("Manual")
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body().add_child(split)

	_list = UiScrollList.new().setup()
	_list.custom_minimum_size.x = 200
	split.add_child(_list)

	_view = TextEdit.new()
	_view.editable = false
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if UiTheme.font("mono"):
		_view.add_theme_font_override("font", UiTheme.font("mono"))
	split.add_child(_view)

	_load_index()
	return self


func _load_index() -> void:
	var dir := DirAccess.open("res://docs")
	if dir == null:
		_list.content().add_child(UiLabel.new().setup("No docs found", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED))
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".md"):
			var card := UiCard.new().setup(fname, "", Color.TRANSPARENT)
			card.pressed.connect(_open_doc.bind(fname))
			_list.content().add_child(card)
		fname = dir.get_next()
	dir.list_dir_end()


func _open_doc(fname: String) -> void:
	var f := FileAccess.open("res://docs/" + fname, FileAccess.READ)
	if f:
		_view.text = f.get_as_text()
