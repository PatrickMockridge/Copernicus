# test_ai_client.gd
# Headless tests for the Anthropic client's parse + connection-test error paths
# (no network needed). Run:
#   godot --headless --script res://scripts/test_ai_client.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	var c := AnthropicClient.new()

	# test_connection with no key must fail loudly without hitting the network.
	var tc := c.test_connection()
	_ok(not tc.get("ok", false), "test_connection no key -> not ok")
	_ok(str(tc.get("error", "")) == "No API key configured", "test_connection no key -> clear error")

	# _parse: Anthropic error body.
	var err := c._parse('{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}')
	_ok(not err.get("ok", false), "parse error body -> not ok")
	_ok(str(err.get("error", "")) == "invalid x-api-key", "parse error body -> message surfaced")

	# _parse: non-JSON body.
	var bad := c._parse("not json")
	_ok(not bad.get("ok", false), "parse non-JSON -> not ok")
	_ok(str(bad.get("error", "")).contains("parse"), "parse non-JSON -> parse error")

	# _parse: valid body with text + tool_use.
	var ok := c._parse('{"content":[{"type":"text","text":"hi"},{"type":"tool_use","id":"a","name":"read_file","input":{"path":"x"}}]}')
	_ok(ok.get("ok", false), "parse valid -> ok")
	_ok(ok.get("text", "") == "hi", "parse valid -> text")
	_ok(ok.get("tool_uses", []).size() == 1, "parse valid -> one tool_use")
	_ok(ok.get("tool_uses", [])[0].get("name", "") == "read_file", "parse valid -> tool name")

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
