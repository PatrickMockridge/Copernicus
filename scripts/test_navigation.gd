# test_navigation.gd
# Headless unit test for NavigationModel / Route. Run:
#   godot --headless --script res://scripts/test_navigation.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	var model := NavigationModel.new()
	model.register(_r("viewer", "Viewer", "design", 0, "viewer.open"))
	model.register(_r("robots", "Robots", "design", 1, "robots.open"))
	model.register(_r("test", "Test", "test", 2, "test.open"))
	model.register(_r("marketplace", "Marketplace", "publish", 3, "marketplace.open"))
	model.register(_r("raas", "RaaS", "operate", 4, "raas.open"))
	model.register(_r("manual", "Manual", "manual", 5, "manual.open"))

	_ok(model.navigate("viewer"), "navigate viewer")
	_ok(model.current().id == "viewer", "current viewer")
	_ok(model.navigate("test"), "navigate test")
	_ok(model.current().id == "test", "current test")
	_ok(model.navigate("nope") == false, "navigate unknown fails")

	var sections := model.sections()
	_ok(sections == ["design", "test", "publish", "operate", "manual"], "sections loop-ordered")
	_ok(model.routes_in_section("design").size() == 2, "design has 2 routes")

	_ok(model.back(), "back to viewer")
	_ok(model.current().id == "viewer", "back lands on viewer")

	_ok(model.resolve_command("marketplace.open") != null, "resolve marketplace.open")
	_ok(model.resolve_command("marketplace.open").id == "marketplace", "resolve -> marketplace")

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _r(id: String, title: String, section: String, order: int, cmd: String) -> Route:
	return Route.make(id, title, "", section, order, cmd, Callable())


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
