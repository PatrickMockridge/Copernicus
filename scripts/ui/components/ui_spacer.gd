# ui_spacer.gd
# A flexible filler that expands on one or both axes.

class_name UiSpacer
extends Control


func setup(horizontal: bool = true, vertical: bool = false) -> UiSpacer:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if horizontal else Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_EXPAND_FILL if vertical else Control.SIZE_SHRINK_BEGIN
	return self
