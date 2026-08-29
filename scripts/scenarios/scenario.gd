# scenario.gd
# A Zachtronics-style "brief": a named objective with pass/fail checks.
# Pure data + the check callables; no rendering.

class_name Scenario
extends RefCounted

var id: String = ""
var title: String = ""
var brief: String = ""
var mode: String = "design"        # design | test | publish | operate
var requires: Array = []           # prerequisite scenario ids (unlock order)
var setup: String = ""             # optional: robot id / "physics_demo" to auto-load on activation
var checks: Array = []             # [{label, check: Callable(ctx)->Variant, expect}]
var manual_refs: Array = []        # pointers into the manual (doc ids), never hints


static func make(p_id: String, p_title: String, p_brief: String, p_mode: String = "design") -> Scenario:
	var s := Scenario.new()
	s.id = p_id
	s.title = p_title
	s.brief = p_brief
	s.mode = p_mode
	return s
