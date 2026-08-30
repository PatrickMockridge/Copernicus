# test_screen_schema.gd
# Headless test for the screen schema: the rail (pinned + in_rail routes) is
# grouped by section and ordered; ai/plugins/manual are not rail entries; every
# rail id resolves. Run:
#   godot --headless --script res://scripts/test_screen_schema.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	var model := NavigationModel.new()
	model.register(_r("editor", "Editor", "▦", "design", 0, true, false))
	model.register(_r("wallet", "Wallet", "◈", "publish", 0, true, false))
	model.register(_r("robots", "Robots", "◧", "design", 1, false, true))
	model.register(_r("marketplace", "Marketplace", "◫", "publish", 1, false, true))
	model.register(_r("coordination", "Coordination", "◍", "publish", 2, false, true))
	model.register(_r("vcs", "Version Control", "⇅", "utility", 0, false, true))
	model.register(_r("raas", "RaaS", "▸", "operate", 0, false, true))
	model.register(_r("ai", "AI Assistant", "◈", "utility", 1, false, false))
	model.register(_r("plugins", "Plugins", "◇", "utility", 3, false, false))
	model.register(_r("manual", "Manual", "▤", "utility", 4, false, false))

	var entries: Array = []
	for r in model.ordered_routes():
		if r.in_activity_bar or r.in_rail:
			entries.append({"id": r.id, "section": r.section})

	_ok(entries.size() == 7, "7 rail entries (2 pinned + 5 screens)")

	var ids: Array = []
	for e in entries:
		ids.append(e["id"])
	_ok(not ids.has("ai"), "ai not in rail")
	_ok(not ids.has("plugins"), "plugins not in rail")
	_ok(not ids.has("manual"), "manual not in rail")

	_ok(ids == ["editor", "robots", "wallet", "marketplace", "coordination", "raas", "vcs"],
		"rail ordered by section then order")

	var all_resolve := true
	for e in entries:
		if model.get_route(e["id"]) == null:
			all_resolve = false
	_ok(all_resolve, "every rail id resolves")

	var sections: Array = []
	for e in entries:
		sections.append(e["section"])
	_ok(sections == ["design", "design", "publish", "publish", "publish", "operate", "utility"],
		"sections contiguous (grouped)")

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _r(id: String, title: String, glyph: String, section: String, order: int, in_bar: bool, in_rail: bool) -> Route:
	var r := Route.make(id, title, glyph, section, order, id + ".open", Callable(), in_bar)
	r.in_rail = in_rail
	return r


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
