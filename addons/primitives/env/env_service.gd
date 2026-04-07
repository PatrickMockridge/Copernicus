# env_service.gd
# Environment variable service - loads .env file and provides API keys
# Supports loading from .env file in project root

extends Node

static var _vars: Dictionary = {}
static var _loaded: bool = false


static func _static_init() -> void:
	load_env()


static func load_env() -> void:
	if _loaded:
		return
	_loaded = true

	var env_path = "res://.env"
	if not FileAccess.file_exists(env_path):
		return

	var file = FileAccess.open(env_path, FileAccess.READ)
	if not file:
		return

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var eq_pos = line.find("=")
		if eq_pos > 0:
			var key = line.substr(0, eq_pos).strip_edges()
			var value = line.substr(eq_pos + 1).strip_edges()
			_vars[key] = value


static func get_var(key: String, default: String = "") -> String:
	if not _loaded:
		load_env()
	return _vars.get(key, default)


static func has_var(key: String) -> bool:
	if not _loaded:
		load_env()
	return _vars.has(key)


static func get_minimax_key() -> String:
	return get_var("MINIMAX_API_KEY", "")


static func get_anthropic_key() -> String:
	return get_var("ANTHROPIC_API_KEY", "")


static func get_openai_key() -> String:
	return get_var("OPENAI_API_KEY", "")
