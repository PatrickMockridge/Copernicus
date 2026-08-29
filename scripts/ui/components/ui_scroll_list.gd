# ui_scroll_list.gd
# A vertically scrolling column of content.

class_name UiScrollList
extends ScrollContainer

var _content: VBoxContainer


func setup() -> UiScrollList:
	set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UiTheme.space("xs"))
	add_child(_content)
	return self


func content() -> VBoxContainer:
	return _content
