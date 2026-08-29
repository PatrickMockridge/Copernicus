# route.gd
# A navigation destination: pure data describing a view and how to reach it.

class_name Route
extends RefCounted

var id: String = ""
var title: String = ""
var glyph: String = ""
var section: String = ""          # design | test | publish | operate | utility | manual
var order: int = 0
var command_id: String = ""        # binds to a CommandRegistry command
var factory: Callable              # -> Control (builds the view)
var sidebar_factory: Callable      # -> Control (optional side-bar content)
var in_activity_bar: bool = true


static func make(
	p_id: String,
	p_title: String,
	p_glyph: String,
	p_section: String,
	p_order: int,
	p_command_id: String,
	p_factory: Callable,
	p_in_activity_bar: bool = true
) -> Route:
	var r := Route.new()
	r.id = p_id
	r.title = p_title
	r.glyph = p_glyph
	r.section = p_section
	r.order = p_order
	r.command_id = p_command_id
	r.factory = p_factory
	r.in_activity_bar = p_in_activity_bar
	return r
