# test_shell.gd
# Headless test for the route guardrails: editor + wallet are the only pinned
# activities; non-core routes are commands/tabs but not activity icons. Also
# asserts view factories are identity-stable (cached) and back/breadcrumb work.
# Run: godot --headless --script res://scripts/test_shell.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	var model := NavigationModel.new()
	var panel_cache: Dictionary = {}

	var editor_factory := func() -> Control: return _cached(panel_cache, "editor")
	var wallet_factory := func() -> Control: return _cached(panel_cache, "wallet")
	var ai_factory := func() -> Control: return _cached(panel_cache, "ai")

	model.register(_r("editor", "Editor", "design", 0, "view.open", true, editor_factory))
	model.register(_r("wallet", "Wallet", "publish", 0, "wallet.open", true, wallet_factory))
	model.register(_r("ai", "AI Assistant", "utility", 1, "ai.open", false, ai_factory))

	# Guardrail: only editor + wallet are pinned activities.
	var activities: Array = []
	for r in model.ordered_routes():
		if r.in_activity_bar:
			activities.append(r.id)
	_ok(activities == ["editor", "wallet"], "activity bar = editor + wallet only")

	# ai is a route (tab/command) but not an activity icon.
	_ok(model.get_route("ai") != null, "ai is a route")
	_ok(model.get_route("ai").in_activity_bar == false, "ai not in activity bar")

	# Factory identity is stable across calls (panels cached, never rebuilt).
	_ok(editor_factory.call() == editor_factory.call(), "editor factory identity-stable")
	_ok(wallet_factory.call() == wallet_factory.call(), "wallet factory identity-stable")

	# back + breadcrumb.
	model.navigate("editor")
	model.navigate("wallet")
	model.navigate("ai")
	var crumb: Array = []
	for r in model.breadcrumb():
		crumb.append(r.id)
	_ok(crumb == ["editor", "wallet", "ai"], "breadcrumb reflects history")
	_ok(model.back(), "back works")
	_ok(model.current_id == "wallet", "back restores prior route")

	# unregister removes a route and blocks navigation.
	model.unregister("ai")
	_ok(model.get_route("ai") == null, "unregister removes route")
	_ok(model.navigate("ai") == false, "navigate to unregistered route fails")

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _cached(cache: Dictionary, id: String) -> Control:
	if not cache.has(id):
		cache[id] = Control.new()
	return cache[id]


func _r(id: String, title: String, section: String, order: int, cmd: String, in_bar: bool, factory: Callable) -> Route:
	return Route.make(id, title, "", section, order, cmd, factory, in_bar)


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
