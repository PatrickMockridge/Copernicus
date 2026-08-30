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
	_http.set_timeout(60.0)


func configure(api_key: String, base_url: String, model: String) -> void:
	_api_key = api_key
	if not base_url.is_empty():
		_base_url = base_url
	if not model.is_empty():
		_model = model


func set_max_tokens(n: int) -> void:
	_max_tokens = n


## Cheap connection/health check: a minimal /v1/messages round-trip that
## exercises the key + endpoint + model. Returns {ok, error, model}.
func test_connection() -> Dictionary:
	if _api_key.is_empty():
		return {"ok": false, "error": "No API key configured"}
	var body := {
		"model": _model,
		"max_tokens": 1,
		"messages": [{"role": "user", "content": [{"type": "text", "text": "ping"}]}],
	}
	var res := _http.post(_endpoint(), _headers(), JSON.stringify(body))
	if res.is_err():
		return {"ok": false, "error": _err_msg(res.err_value())}
	var parsed := _parse(str(res.ok_value()))
	if not parsed.get("ok", false):
		return parsed
	return {"ok": true, "error": "", "model": _model}


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

	var res := _http.post(_endpoint(), _headers(), JSON.stringify(body))
	if res.is_err():
		return {"ok": false, "error": _err_msg(res.err_value())}
	return _parse(str(res.ok_value()))


func _err_msg(e) -> String:
	var msg := ""
	if e is Dictionary:
		msg = str(e.get("message", ""))
	else:
		msg = str(e)
	if msg.strip_edges().is_empty():
		msg = "request failed"
	return msg


func _endpoint() -> String:
	return _base_url + "/v1/messages"


func _headers() -> Array:
	return [
		"x-api-key: " + _api_key,
		"Authorization: Bearer " + _api_key,
		"anthropic-version: 2023-06-01",
		"content-type: application/json",
	]


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
