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


## Commands this module contributes to the terminal (and the command palette).
## Returns [{name, syntax, description, category, handler}].
## `handler` is a static Callable(args: Array, out: Callable) -> bool: it receives
## the parsed args and a line-writer, and returns true on success (writing a
## "?"-prefixed error on failure). Default: none.
static func get_commands() -> Array:
	return []
