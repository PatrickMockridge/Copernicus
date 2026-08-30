# agent.gd
# The agentic loop: alternate between Claude (with tools) and tool execution
# until Claude produces a final answer. Runs synchronously (blocking) and is
# meant to be executed on a TaskRunner worker thread.

class_name AgentController
extends RefCounted

const AnthropicClient = preload("res://scripts/ai/anthropic_client.gd")
const AiTools = preload("res://scripts/ai/tools.gd")

const MAX_TURNS := 20

const SYSTEM_PROMPT := "You are a coding agent inside Copernicus, a Godot 4 robot-design interface (GDScript, .tscn scenes, ROS 2). You have tools to read, write, and edit files directly in the project. When asked to implement or fix something, use your tools to create or modify the real files — never tell the user to copy-paste code. Work step by step: read the relevant files first, then edit them."

var _client: AnthropicClient
var _tools: AiTools


func _init() -> void:
	_client = AnthropicClient.new()
	_tools = AiTools.new(_workspace_path())


## The directory the agent codes in — a user workspace, never the Copernicus
## source tree. From Settings (workspace) → .env AI_WORKSPACE → ~/robot_workspace.
func _workspace_path() -> String:
	var ws := str(SettingsStore.resolve_ai()["workspace"])
	if ws.begins_with("~/"):
		ws = OS.get_environment("HOME") + ws.substr(1)
	if not DirAccess.dir_exists_absolute(ws):
		DirAccess.make_dir_recursive_absolute(ws)
	return ws


func is_configured() -> bool:
	return not str(SettingsStore.resolve_ai()["api_key"]).is_empty()


## Run the agent. `history` is prior {role, content} messages in block format.
## Returns {ok, error, text, events:[{kind, ...}]}.
func run(task: String, history: Array) -> Dictionary:
	var ai := SettingsStore.resolve_ai()
	_client.configure(ai["api_key"], ai["base_url"], ai["model"])

	var events: Array = []
	var messages: Array = []
	for m in history:
		messages.append(m)
	messages.append({"role": "user", "content": [{"type": "text", "text": task}]})

	var schemas := _tools.tool_schemas()
	var final_text := ""
	var done := false

	for turn in MAX_TURNS:
		var res := _client.send(messages, schemas, SYSTEM_PROMPT)
		if not res.get("ok", false):
			events.append({"kind": "error", "text": str(res.get("error", ""))})
			return {"ok": false, "error": str(res.get("error", "")), "events": events}

		var tool_uses: Array = res.get("tool_uses", [])
		var text := str(res.get("text", ""))
		var assistant_content: Array = []
		if not text.is_empty():
			assistant_content.append({"type": "text", "text": text})
			events.append({"kind": "message", "text": text})

		if tool_uses.is_empty():
			final_text = text
			done = true
			break

		for tu in tool_uses:
			assistant_content.append({"type": "tool_use", "id": tu["id"], "name": tu["name"], "input": tu["input"]})
			events.append({"kind": "tool_called", "name": tu["name"], "input": tu["input"]})
		messages.append({"role": "assistant", "content": assistant_content})

		var tool_results: Array = []
		for tu in tool_uses:
			var r := _tools.execute(tu["name"], tu["input"])
			var ok: bool = r.get("ok", false)
			var content := str(r.get("result", "")) if ok else ("Error: " + str(r.get("error", "")))
			tool_results.append({"type": "tool_result", "tool_use_id": tu["id"], "content": content})
			events.append({"kind": "tool_result", "name": tu["name"], "ok": ok, "content": content})
		messages.append({"role": "user", "content": tool_results})

	if not done:
		events.append({"kind": "message", "text": "… (stopped after %d tool turns)" % MAX_TURNS})

	return {"ok": true, "text": final_text, "messages": messages, "events": events}
