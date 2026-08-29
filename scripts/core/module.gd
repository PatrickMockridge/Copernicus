# module.gd
# Lightweight base class for all Copernicus plugin modules.
# Every backend module extends this and overrides the five static contract methods.

class_name CopernicusModule
extends RefCounted


static func get_module_name() -> String:
	return "Unknown"


static func get_module_description() -> String:
	return ""


static func is_available() -> bool:
	return false


static func get_requirements() -> String:
	return ""


static func get_module_category() -> String:
	return ""


## Commands this module contributes to the command palette.
## Returns [{id, label, category, keywords, handler: Callable}]. Default: none.
static func get_commands() -> Array:
	return []
