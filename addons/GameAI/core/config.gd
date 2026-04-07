# config.gd
# AI Configuration - Manage API keys for different providers

class_name AIConfig

var _providers: Dictionary = {}
var _default: String = "anthropic"


func configure(config: Dictionary) -> void:
	# Configure providers
	# config = {
	#   "anthropic": {"api_key": "sk-..."},
	#   "openai": {"api_key": "sk-..."},
	#   "minimax": {"api_key": "..."},
	#   "default": "anthropic"
	# }
	for key in config.keys():
		if key == "default":
			_default = config[key]
		elif _providers.has(key) or key in ["anthropic", "openai", "minimax", "custom"]:
			_providers[key] = config[key]


func get_provider_key(provider: String) -> String:
	if _providers.has(provider):
		return _providers[provider].get("api_key", "")
	return ""


func get_provider_base_url(provider: String) -> String:
	if _providers.has(provider):
		return _providers[provider].get("base_url", "")
	return ""


func has_provider(provider: String) -> bool:
	return _providers.has(provider) and _providers[provider].has("api_key")


func set_provider_key(provider: String, api_key: String) -> void:
	if not _providers.has(provider):
		_providers[provider] = {}
	_providers[provider]["api_key"] = api_key


func get_all_providers() -> Array:
	return _providers.keys()


func get_default() -> String:
	return _default


func set_default(provider: String) -> void:
	_default = provider


# === Provider Metadata ===

const PROVIDER_INFO: Dictionary = {
	"anthropic": {
		"name": "Anthropic Claude",
		"models": [
			"claude-3-5-sonnet-20241022",
			"claude-3-opus-20240229",
			"claude-3-haiku-20240307"
		],
		"endpoint": "https://api.anthropic.com/v1/messages",
		"supports_streaming": true,
		"supports_system_prompts": true
	},
	"openai": {
		"name": "OpenAI",
		"models": [
			"gpt-4o",
			"gpt-4-turbo",
			"gpt-3.5-turbo"
		],
		"endpoint": "https://api.openai.com/v1/chat/completions",
		"supports_streaming": true,
		"supports_system_prompts": true
	},
	"minimax": {
		"name": "Minimax",
		"models": [
			"MiniMax-Text-01"
		],
		"endpoint": "https://api.minimax.chat/v1/text/chatcompletion_v2",
		"supports_streaming": false,
		"supports_system_prompts": true
	}
}


func get_provider_info(provider: String) -> Dictionary:
	return PROVIDER_INFO.get(provider, {})


func list_models(provider: String) -> Array:
	var info = get_provider_info(provider)
	return info.get("models", [])


func supports_streaming(provider: String) -> bool:
	var info = get_provider_info(provider)
	return info.get("supports_streaming", false)
