# test_state.gd
# Headless unit test for the state-transition guards (docs/spec/05):
#   G2 breadcrumbing, G3 reversibility, and the route_changed contract.
# G1 (no change_scene_to_file) and G4 (view identity) are verified by grep /
# the running app, not here. Run:
#   godot --headless --script res://scripts/test_state.gd

extends SceneTree

var _fails := 0
var _emits := 0


func _init() -> void:
	_test_breadcrumb()
	_test_reversibility()
	_test_route_changed_contract()
	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _r(id: String, title: String) -> Route:
	return Route.make(id, title, "", "design", 0, "", Callable())


func _track(model: NavigationModel) -> void:
	model.route_changed.connect(func(_from: String, _to: String) -> void: _emits += 1)


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1


func _test_breadcrumb() -> void:
	print("== breadcrumb (G2) ==")
	var model := NavigationModel.new()
	var a := _r("a", "A")
	var b := _r("b", "B")
	var c := _r("c", "C")
	model.register(a)
	model.register(b)
	model.register(c)

	_ok(model.breadcrumb().is_empty(), "breadcrumb empty before any navigate")
	model.navigate("a")
	_ok(model.breadcrumb().size() == 1 and model.breadcrumb()[0] == a, "breadcrumb == [A] after navigate a")
	model.navigate("b")
	_ok(model.breadcrumb().size() == 2 and model.breadcrumb()[1] == b, "breadcrumb == [A, B] after navigate b")
	_ok(model.history() == ["a"], "history == [a] while at b")


func _test_reversibility() -> void:
	print("== reversibility (G3) ==")
	var model := NavigationModel.new()
	model.register(_r("a", "A"))
	model.register(_r("b", "B"))
	model.register(_r("c", "C"))

	model.navigate("a")
	model.navigate("b")
	model.navigate("c")
	_ok(model.current().id == "c", "at c")
	_ok(model.back(), "back c -> b")
	_ok(model.current().id == "b", "back lands on b")
	_ok(model.back(), "back b -> a")
	_ok(model.current().id == "a", "back lands on a")
	_ok(model.back() == false, "back at root returns false")
	_ok(model.current().id == "a", "still at a after failed back")


func _test_route_changed_contract() -> void:
	print("== route_changed contract ==")
	var model := NavigationModel.new()
	model.register(_r("a", "A"))
	model.register(_r("b", "B"))
	_track(model)
	_emits = 0

	model.navigate("a")
	_ok(_emits == 1, "navigate a emits once")
	model.navigate("a")
	_ok(_emits == 1, "re-navigate same route does not emit")
	model.navigate("b")
	_ok(_emits == 2, "navigate b emits once")
	model.back()
	_ok(_emits == 3, "back emits once")
