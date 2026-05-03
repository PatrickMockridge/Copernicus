# module_registry.gd
# Autoload singleton — the central registry for all plugin modules.
# Backends register themselves via _static_init(); selectors query via get_available().

extends Node

var _modules: Dictionary = {}


func register(category: String, id: String, script: GDScript) -> void:
	if not _modules.has(category):
		_modules[category] = {}
	_modules[category][id] = script


func get_available(category: String) -> Array:
	var result: Array = []
	if not _modules.has(category):
		return result

	var available_list: Array = []
	var unavailable_list: Array = []

	for id in _modules[category]:
		var scr = _modules[category][id]
		var info = {
			"id": id,
			"name": scr.get_module_name(),
			"description": scr.get_module_description(),
			"available": scr.is_available(),
			"requirements": scr.get_requirements(),
			"category": category
		}
		if info["available"]:
			available_list.append(info)
		else:
			unavailable_list.append(info)

	result.append_array(available_list)
	result.append_array(unavailable_list)
	return result


func create(category: String, id: String, config: Dictionary = {}):
	if not _modules.has(category) or not _modules[category].has(id):
		push_error("ModuleRegistry: no module '%s' in category '%s'" % [id, category])
		return null
	var instance = _modules[category][id].new()
	if not config.is_empty() and instance.has_method("initialize"):
		instance.initialize(config)
	return instance


func get_info(category: String, id: String) -> Dictionary:
	if not _modules.has(category) or not _modules[category].has(id):
		return {}
	var scr = _modules[category][id]
	return {
		"id": id,
		"name": scr.get_module_name(),
		"description": scr.get_module_description(),
		"available": scr.is_available(),
		"requirements": scr.get_requirements(),
		"category": category
	}


func get_all_categories() -> Array:
	return _modules.keys()


func has_module(category: String, id: String) -> bool:
	return _modules.has(category) and _modules[category].has(id)
