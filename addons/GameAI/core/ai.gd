# ai.gd
# GameAI SDK - AI integration for Godot 4
# Supports Anthropic Claude, OpenAI, Minimax, and custom AI providers

extends Node

const VERSION = "1.0.0"

const AIConfig = preload("res://addons/GameAI/core/config.gd")
const HttpClient = preload("res://addons/GameAI/core/http_client.gd")
const Result = preload("res://addons/GameAI/core/result.gd")

var _config: AIConfig
var _http: HttpClient
var _active_provider: String = ""


func _init() -> void:
	_config = AIConfig.new()
	_http = HttpClient.new()
	add_child(_http)


func configure(config: Dictionary) -> void:
	# Configure AI providers with API keys
	# config = {
	#   "anthropic": {"api_key": "sk-..."},
	#   "openai": {"api_key": "sk-..."},
	#   "minimax": {"api_key": "..."},
	#   "default": "anthropic"
	# }
	_config.configure(config)
	if config.has("default"):
		_active_provider = config["default"]


func get_config() -> AIConfig:
	return _config


func set_default_provider(provider: String) -> void:
	_active_provider = provider


func get_default_provider() -> String:
	return _active_provider if _active_provider != "" else "anthropic"


# === Chat Completions ===

func chat(messages: Array, params: Dictionary = {}) -> Result:
	# Send chat request to configured provider
	# messages: [{"role": "user", "content": "..."}]
	# params: Optional provider-specific parameters
	var provider = params.get("provider", get_default_provider())
	return _send_chat(provider, messages, params)


func chat_system(system: String, user_message: String, params: Dictionary = {}) -> Result:
	# Convenience: single chat with system prompt
	return chat([{"role": "system", "content": system}, {"role": "user", "content": user_message}], params)


func _send_chat(provider: String, messages: Array, params: Dictionary) -> Result:
	match provider:
		"anthropic":
			return _anthropic_chat(messages, params)
		"openai":
			return _openai_chat(messages, params)
		"minimax":
			return _minimax_chat(messages, params)
		_:
			return Result.err({"code": -1, "message": "Unknown provider: " + provider})


# === Anthropic Claude ===

func _anthropic_chat(messages: Array, params: Dictionary) -> Result:
	var api_key = _config.get_provider_key("anthropic")
	if api_key == "":
		return Result.err({"code": -2, "message": "Anthropic API key not configured"})

	var endpoint = "https://api.anthropic.com/v1/messages"
	var headers = [
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01",
		"content-type: application/json"
	]

	var body = {
		"messages": _filter_anthropic_messages(messages),
		"model": params.get("model", "claude-3-5-sonnet-20241022"),
		"max_tokens": params.get("max_tokens", 1024)
	}

	if params.has("system"):
		body["system"] = params["system"]

	var response = _http.post(endpoint, headers, JSON.stringify(body))
	if response.is_err():
		return response
	return _parse_anthropic_response(response.ok_value)


func _filter_anthropic_messages(messages: Array) -> Array:
	# Anthropic doesn't support system messages in the messages array
	var filtered = []
	for msg in messages:
		if msg.get("role") == "system":
			continue  # System prompts go in separate field
		filtered.append(msg)
	return filtered


func _parse_anthropic_response(response_text: String) -> Result:
	var json = JSON.parse_string(response_text)
	if json == null:
		return Result.err({"code": -3, "message": "Failed to parse Anthropic response"})
	if json.has("error"):
		return Result.err({"code": -4, "message": json.error.message})
	var content = json.content[0].text if json.has("content") else ""
	return Result.ok({
		"content": content,
		"provider": "anthropic",
		"model": json.model if json.has("model") else ""
	})


# === OpenAI ===

func _openai_chat(messages: Array, params: Dictionary) -> Result:
	var api_key = _config.get_provider_key("openai")
	if api_key == "":
		return Result.err({"code": -2, "message": "OpenAI API key not configured"})

	var endpoint = "https://api.openai.com/v1/chat/completions"
	var headers = [
		"Authorization: Bearer " + api_key,
		"content-type: application/json"
	]

	var body = {
		"messages": messages,
		"model": params.get("model", "gpt-4o"),
		"max_tokens": params.get("max_tokens", 1024)
	}

	if params.has("temperature"):
		body["temperature"] = params["temperature"]
	if params.has("top_p"):
		body["top_p"] = params["top_p"]

	var response = _http.post(endpoint, headers, JSON.stringify(body))
	if response.is_err():
		return response
	return _parse_openai_response(response.ok_value)


func _parse_openai_response(response_text: String) -> Result:
	var json = JSON.parse_string(response_text)
	if json == null:
		return Result.err({"code": -3, "message": "Failed to parse OpenAI response"})
	if json.has("error"):
		return Result.err({"code": -4, "message": json.error.message})
	var content = json.choices[0].message.content if json.has("choices") else ""
	return Result.ok({
		"content": content,
		"provider": "openai",
		"model": json.model if json.has("model") else ""
	})


# === Minimax ===

func _minimax_chat(messages: Array, params: Dictionary) -> Result:
	var api_key = _config.get_provider_key("minimax")
	if api_key == "":
		return Result.err({"code": -2, "message": "Minimax API key not configured"})

	var endpoint = "https://api.minimax.chat/v1/text/chatcompletion_v2"
	var headers = [
		"Authorization: Bearer " + api_key,
		"content-type: application/json"
	]

	var body = {
		"messages": messages,
		"model": params.get("model", "MiniMax-Text-01"),
		"max_tokens": params.get("max_tokens", 1024)
	}

	if params.has("temperature"):
		body["temperature"] = params["temperature"]

	var response = _http.post(endpoint, headers, JSON.stringify(body))
	if response.is_err():
		return response
	return _parse_minimax_response(response.ok_value)


func _parse_minimax_response(response_text: String) -> Result:
	var json = JSON.parse_string(response_text)
	if json == null:
		return Result.err({"code": -3, "message": "Failed to parse Minimax response"})
	if json.has("base_resp") and json.base_resp.has("status_code"):
		if json.base_resp.status_code != 0:
			return Result.err({"code": -4, "message": json.base_resp.status_msg})
	var content = json.choices[0].messages[0].text if json.has("choices") else ""
	return Result.ok({
		"content": content,
		"provider": "minimax",
		"model": json.model if json.has("model") else ""
	})


# === Code Generation (Claude only for now) ===

func generate_code(task: String, language: String = "gdscript") -> Result:
	# Generate code using AI
	return chat_system(
		"You are an expert " + language + " programmer. Write clean, efficient code.",
		"Write " + language + " code for: " + task,
		{"provider": "anthropic", "max_tokens": 2048}
	)


func explain_code(code: String) -> Result:
	# Explain what code does
	return chat([
		{"role": "user", "content": "Explain this code:\n\n" + code}
	], {"provider": "anthropic"})


# === NPC Dialogue ===

var _npc_contexts: Dictionary = {}


func npc_init(npc_id: String, personality: String, lore: String = "") -> void:
	# Initialize an NPC with personality and lore
	_npc_contexts[npc_id] = {
		"personality": personality,
		"lore": lore,
		"history": []
	}


func npc_say(npc_id: String, player_message: String) -> Result:
	# Get NPC response to player message
	if not _npc_contexts.has(npc_id):
		return Result.err({"code": -1, "message": "NPC not initialized: " + npc_id})

	var ctx = _npc_contexts[npc_id]
	var system = "You are a game NPC with this personality: " + ctx.personality
	if ctx.lore != "":
		system += "\n\nYour lore/background: " + ctx.lore

	ctx.history.append({"role": "user", "content": player_message})

	var result = chat_system(system, player_message, {"provider": get_default_provider()})

	if result.is_ok():
		ctx.history.append({"role": "assistant", "content": result.ok_value.content})

	return result


func npc_clear_history(npc_id: String) -> void:
	if _npc_contexts.has(npc_id):
		_npc_contexts[npc_id].history = []


# === World Building ===

func generate_quest(theme: String, difficulty: String = "medium") -> Result:
	# Generate a quest for your game
	var prompt = """Generate a game quest with the following:
Theme: %s
Difficulty: %s

Provide:
- Quest name
- Objective
- Description
- Rewards (XP and items)
- Enemies/obstacles

Format as structured text.""" % [theme, difficulty]

	return chat([
		{"role": "user", "content": prompt}
	], {"max_tokens": 1024})


func generate_item_name(item_type: String, rarity: String = "common") -> Result:
	# Generate a randomized item name
	var prompt = "Generate a %s %s item name. Just give the name, nothing else." % [rarity, item_type]
	return chat([{"role": "user", "content": prompt}], {"max_tokens": 64})


func generate_dungeon_layout(size: String = "medium", theme: String = "dungeon") -> Result:
	# Generate dungeon layout/description
	var prompt = """Describe a %s %s dungeon layout.
Include:
- Number of rooms
- Key features (traps, treasures, enemies)
- Boss room location
- Secret areas

Be creative and specific.""" % [size, theme]

	return chat([{"role": "user", "content": prompt}], {"max_tokens": 1024})


# === AI Assistant (In-Game Helper) ===

func ask_about_game(game_context: String, question: String) -> Result:
	# In-game help/assistant
	var system = "You are a helpful game assistant. Answer questions about the game based on the provided context."
	return chat_system(system, "Context: " + game_context + "\n\nQuestion: " + question)


# === Streaming (Basic) ===

signal chat_stream_chunk(chunk: String, provider: String)

func chat_stream(messages: Array, params: Dictionary = {}) -> Result:
	# Streaming chat - emits signals for each chunk
	# Note: Requires provider support
	var provider = params.get("provider", get_default_provider())
	match provider:
		"anthropic":
			return _anthropic_stream(messages, params)
		_:
			return Result.err({"code": -1, "message": "Streaming not supported for " + provider})


func _anthropic_stream(messages: Array, params: Dictionary) -> Result:
	var api_key = _config.get_provider_key("anthropic")
	if api_key == "":
		return Result.err({"code": -2, "message": "Anthropic API key not configured"})

	var endpoint = "https://api.anthropic.com/v1/messages"
	var headers = [
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01",
		"content-type: application/json"
	]

	var body = {
		"messages": _filter_anthropic_messages(messages),
		"model": params.get("model", "claude-3-5-sonnet-20241022"),
		"max_tokens": params.get("max_tokens", 1024),
		"stream": true
	}

	if params.has("system"):
		body["system"] = params["system"]

	var response = _http.post_stream(endpoint, headers, JSON.stringify(body))
	return response


# === Utility ===

func get_version() -> String:
	return VERSION
