# anthropic_client.gd
# Thin, tools-aware client for the Anthropic Messages API (/v1/messages).
# Returns parsed text + tool_use blocks. Transport reuses GameAIHttpClient (curl).

class_name AnthropicClient
extends RefCounted

const GameAIHttpClient = preload("res://addons/GameAI/core/http_client.gd")

var _http: GameAIHttpClient
var _api_key: String = ""
var _base_url: String = "https://api.anthropic.com"
var _model: String = "claude-sonnet-4-6"
var _max_tokens: int = 8192


func _init() -> void:
	_http = GameAIHttpClient.new()
	_http.set_timeout(120.0)


func configure(api_key: String, base_url: String, model: String) -> void:
	_api_key = api_key
	if not base_url.is_empty():
		_base_url = base_url
	if not model.is_empty():
		_model = model


func set_max_tokens(n: int) -> void:
	_max_tokens = n


## Send one Messages API turn. `messages` are already in Anthropic block format
## (each item is {role, content} where content is an array of blocks).
## Returns {ok, error, text, tool_uses:[{id,name,input}]}.
func send(messages: Array, tools: Array, system: String) -> Dictionary:
	if _api_key.is_empty():
		return {"ok": false, "error": "Anthropic API key not configured"}

	var body := {
		"model": _model,
		"max_tokens": _max_tokens,
		"messages": messages,
	}
	if not system.is_empty():
		body["system"] = system
	if not tools.is_empty():
		body["tools"] = tools

	var headers := [
		"x-api-key: " + _api_key,
		"Authorization: Bearer " + _api_key,
		"anthropic-version: 2023-06-01",
		"content-type: application/json",
	]
	var endpoint := _base_url + "/v1/messages"

	var res = _http.post(endpoint, headers, JSON.stringify(body))
	if res.is_err():
		var e = res.err_value()
		var msg = e.get("message", str(e)) if e is Dictionary else str(e)
		return {"ok": false, "error": msg}
	return _parse(str(res.ok_value()))


func _parse(response_text: String) -> Dictionary:
	var json = JSON.parse_string(response_text)
	if json == null:
		return {"ok": false, "error": "Failed to parse Anthropic response"}
	if json is Dictionary and json.has("error"):
		var e = json["error"]
		return {"ok": false, "error": str(e.get("message", e) if e is Dictionary else e)}

	var text := ""
	var tool_uses: Array = []
	var content = json.get("content", [])
	if content is Array:
		for block in content:
			if not (block is Dictionary):
				continue
			match str(block.get("type", "")):
				"text":
					text += str(block.get("text", ""))
				"tool_use":
					tool_uses.append({
						"id": str(block.get("id", "")),
						"name": str(block.get("name", "")),
						"input": block.get("input", {}),
					})
	return {"ok": true, "text": text, "tool_uses": tool_uses}
