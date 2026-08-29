# test_scenarios.gd
# Headless unit test for the Workbench Loop models (Scenario / ProgressionModel /
# ScenarioEvaluator). Run: godot --headless --script res://scripts/test_scenarios.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	_test_progression()
	_test_evaluator()
	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1


func _test_progression() -> void:
	print("== progression ==")
	var model := ProgressionModel.new()
	var s0 := Scenario.make("a", "A", "do a")
	var s1 := Scenario.make("b", "B", "do b")
	s1.requires = ["a"]
	var s2 := Scenario.make("c", "C", "do c")
	s2.requires = ["b"]
	model.register(s0)
	model.register(s1)
	model.register(s2)

	_ok(model.is_unlocked("a"), "a unlocked (no requires)")
	_ok(not model.is_unlocked("b"), "b locked (requires a)")
	_ok(not model.is_unlocked("c"), "c locked (requires b)")
	_ok(model.next_unlocked() == "a", "next_unlocked == a")

	model.complete("a")
	_ok(model.is_completed("a"), "a completed")
	_ok(model.is_unlocked("b"), "b unlocked after a")
	_ok(model.next_unlocked() == "b", "next_unlocked == b")

	model.activate("b")
	_ok(model.current() == s1, "activate b -> current b")
	model.activate("c")
	_ok(model.current() == s1, "activate locked c ignored")

	model.complete("b")
	_ok(model.is_unlocked("c"), "c unlocked after b")
	_ok(model.next_unlocked() == "c", "next_unlocked == c")


func _test_evaluator() -> void:
	print("== evaluator ==")
	var s := Scenario.make("x", "X", "do x")
	s.checks = [{"label": "flag", "check": func(ctx) -> Variant: return ctx.get("flag", false), "expect": true}]

	var ok_ctx := {"flag": true}
	var r := ScenarioEvaluator.evaluate(s, ok_ctx)
	_ok(r.passed, "passes when flag=true")
	_ok(r.checks[0]["ok"], "check ok true")

	var bad_ctx := {"flag": false}
	var r2 := ScenarioEvaluator.evaluate(s, bad_ctx)
	_ok(not r2.passed, "fails when flag=false")
	_ok(r2.checks[0]["actual"] == false, "actual false reported")

	var missing_ctx := {}
	var r3 := ScenarioEvaluator.evaluate(s, missing_ctx)
	_ok(not r3.passed, "fails when key missing (defaults false)")
