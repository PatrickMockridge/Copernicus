# validation_result.gd
# The outcome of evaluating a Scenario's checks against a context.

class_name ValidationResult
extends RefCounted

var passed: bool = false
var checks: Array = []      # [{label, ok, actual, expected}]
var metrics: Dictionary = {}
var message: String = ""


static func build(p_checks: Array, p_metrics: Dictionary = {}, p_message: String = "") -> ValidationResult:
	var r := ValidationResult.new()
	r.checks = p_checks
	r.metrics = p_metrics
	r.message = p_message
	r.passed = true
	for c in p_checks:
		if not bool(c.get("ok", false)):
			r.passed = false
			break
	return r
