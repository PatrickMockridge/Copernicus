# settings_store.gd
# Shared user settings, persisted to user://settings.json. Static (no scene
# state), so it can be read from worker threads (e.g. the AI agent).

class_name SettingsStore

const SETTINGS_PATH := "user://settings.json"
const LEGACY_AI_PATH := "user://ai_config.json"


static func read() -> Dictionary:
	var d := _read_json(SETTINGS_PATH)
	if not d.has("ai"):
		var legacy := _read_json(LEGACY_AI_PATH)
		if not legacy.is_empty():
			d["ai"] = legacy
	return d


static func write(d: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


static func get_ai() -> Dictionary:
	var d := read()
	if d.has("ai") and d["ai"] is Dictionary:
		return d["ai"]
	return {}


static func set_ai(ai: Dictionary) -> void:
	var d := read()
	d["ai"] = ai
	write(d)


## Effective AI config: settings → .env → defaults.
static func resolve_ai() -> Dictionary:
	var ai := get_ai()
	var key := str(ai.get("api_key", ""))
	if key.is_empty():
		key = EnvService.get_anthropic_key()
	var base_url := str(ai.get("base_url", ""))
	if base_url.is_empty():
		base_url = EnvService.get_var("ANTHROPIC_BASE_URL")
	if base_url.is_empty():
		base_url = "https://api.anthropic.com"
	var model := str(ai.get("model", ""))
	if model.is_empty():
		model = EnvService.get_var("ANTHROPIC_MODEL")
	if model.is_empty():
		model = "claude-sonnet-4-6"
	var workspace := str(ai.get("workspace", ""))
	if workspace.is_empty():
		workspace = EnvService.get_var("AI_WORKSPACE")
	if workspace.is_empty():
		workspace = OS.get_environment("HOME") + "/robot_workspace"
	return {"api_key": key, "base_url": base_url, "model": model, "workspace": workspace}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
