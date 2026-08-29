# progression_model.gd
# The scenario ladder: definitions, current selection, completion, and the
# unlock graph (a scenario is unlocked when all its prerequisites are complete).

class_name ProgressionModel
extends RefCounted

signal scenario_changed(current_id: String)

var _scenarios: Dictionary = {}  # id -> Scenario
var _order: Array = []           # ids in registration order
var current_id: String = ""
var _completed: Dictionary = {}  # id -> true


func register(scenario: Scenario) -> void:
	_scenarios[scenario.id] = scenario
	if not _order.has(scenario.id):
		_order.append(scenario.id)


func get_scenario(id: String) -> Scenario:
	return _scenarios.get(id)


func get_order() -> Array:
	return _order.duplicate()


func activate(id: String) -> void:
	if not _scenarios.has(id):
		return
	if not is_unlocked(id):
		return
	current_id = id
	scenario_changed.emit(current_id)


func current() -> Scenario:
	return _scenarios.get(current_id)


func complete(id: String) -> void:
	if _scenarios.has(id) and not _completed.has(id):
		_completed[id] = true
		scenario_changed.emit(current_id)


func is_completed(id: String) -> bool:
	return _completed.has(id)


func is_unlocked(id: String) -> bool:
	if not _scenarios.has(id):
		return false
	var sc: Scenario = _scenarios[id]
	for req in sc.requires:
		if not _completed.has(req):
			return false
	return true


## The first registered scenario that is unlocked and not yet completed, or "".
func next_unlocked() -> String:
	for id in _order:
		if not _completed.has(id) and is_unlocked(id):
			return id
	return ""
