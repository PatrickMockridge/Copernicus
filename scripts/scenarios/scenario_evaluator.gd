# scenario_evaluator.gd
# Pure evaluation: run a Scenario's checks against a context dictionary and
# produce a ValidationResult. No rendering, no autoload dependencies.

class_name ScenarioEvaluator
extends RefCounted


static func evaluate(scenario: Scenario, context: Dictionary) -> ValidationResult:
	var checks: Array = []
	for c in scenario.checks:
		var check: Callable = c["check"]
		var expect = c.get("expect", true)
		var actual = check.call(context)
		var ok: bool = (actual == expect)
		checks.append({
			"label": c.get("label", ""),
			"ok": ok,
			"actual": actual,
			"expected": expect,
		})
	var message := "COMPLETE" if _all_ok(checks) else "In progress"
	return ValidationResult.build(checks, {}, message)


static func _all_ok(checks: Array) -> bool:
	for c in checks:
		if not bool(c.get("ok", false)):
			return false
	return true
