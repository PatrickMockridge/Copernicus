# main.gd
# Agentic AI assistant panel. Claude (Anthropic, tool-use) reads and edits a
# user workspace directly via tools. The panel is a plain chat: prompt in,
# Claude codes, you read the conversation.

class_name AiAssistantPanel
extends Control

const AgentController = preload("res://scripts/ai/agent.gd")

var _status_label: UiLabel
var _chat_scroll: ScrollContainer
var _chat_log: VBoxContainer
var _input: TextEdit
var _send_btn: Button

var _history: Array = []
var _running: bool = false


func _ready() -> void:
	_setup_ui()
	_update_status()


func _setup_ui() -> void:
	var win = UiPanel.new().setup("AI Assistant")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)
	var body: VBoxContainer = win.body()

	_status_label = UiLabel.new().setup("", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED)
	body.add_child(_status_label)

	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_chat_scroll)

	_chat_log = VBoxContainer.new()
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_constant_override("separation", UiTheme.space("s"))
	_chat_scroll.add_child(_chat_log)

	_input = TextEdit.new()
	_input.custom_minimum_size.y = 56
	_input.custom_minimum_size.x = 0
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.placeholder_text = "Ask Claude to build or fix something…"
	body.add_child(_input)

	var send_row := HBoxContainer.new()
	send_row.add_theme_constant_override("separation", UiTheme.space("s"))
	body.add_child(send_row)

	_send_btn = Button.new()
	_send_btn.text = "Send"
	_send_btn.pressed.connect(_on_send)
	send_row.add_child(_send_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear)
	send_row.add_child(clear_btn)


func set_viewer(_viewer: Node) -> void:
	pass  # the agent reads the workspace directly; viewer wiring is not needed


func _update_status() -> void:
	if EnvService.get_anthropic_key().is_empty():
		_status_label.text = "Not connected — set ANTHROPIC_API_KEY in .env"
	else:
		_status_label.text = "Connected (Claude/Anthropic)"


func _on_send() -> void:
	if _running:
		return
	var prompt := _input.text.strip_edges()
	if prompt.is_empty():
		return
	_append(UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY, "You: " + prompt)
	_input.text = ""
	_running = true
	_send_btn.disabled = true
	_status_label.text = "Working…"

	var history: Array = _history.duplicate()
	var action := func() -> Dictionary:
		var agent := AgentController.new()
		return agent.run(prompt, history)
	RChainService.run(action, _on_run_done)


func _on_run_done(result) -> void:
	_running = false
	_send_btn.disabled = false
	_update_status()
	if result == null:
		_append(UiLabel.Kind.BODY, UiLabel.Tone.ERROR, "Error: no result")
		return
	if not result.get("ok", false):
		_append(UiLabel.Kind.BODY, UiLabel.Tone.ERROR, "Error: " + str(result.get("error", "")))
		return
	_history = result.get("messages", [])
	for e in result.get("events", []):
		_apply_event(e)


func _on_clear() -> void:
	_history = []
	for c in _chat_log.get_children():
		_chat_log.remove_child(c)
		c.queue_free()


func _apply_event(e: Dictionary) -> void:
	match str(e.get("kind", "")):
		"message":
			_append(UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY, "Claude: " + str(e.get("text", "")))
		"tool_called":
			var name := str(e.get("name", ""))
			var input: Dictionary = e.get("input", {})
			var arg := str(input.get("path", input.get("query", input.get("old_string", ""))))
			if arg.length() > 60:
				arg = arg.substr(0, 60) + "…"
			_append(UiLabel.Kind.SMALL, UiLabel.Tone.MUTED, "⚙ " + name + ((": " + arg) if not arg.is_empty() else ""))
		"tool_result":
			var name := str(e.get("name", ""))
			var ok: bool = e.get("ok", false)
			var tone := UiLabel.Tone.SUCCESS if ok else UiLabel.Tone.ERROR
			_append(UiLabel.Kind.SMALL, tone, ("✓ " if ok else "✗ ") + name)
		"error":
			_append(UiLabel.Kind.BODY, UiLabel.Tone.ERROR, str(e.get("text", "")))


func _append(kind: UiLabel.Kind, tone: UiLabel.Tone, text: String) -> void:
	_chat_log.add_child(UiLabel.new().setup(text, kind, tone))
	_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)
