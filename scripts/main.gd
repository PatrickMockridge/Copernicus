# main.gd
# Agentic AI assistant panel. Claude reads/edits a user workspace. Configuration
# (key, endpoint, model, workspace) lives in Settings; this panel shows the
# connection status and a chat.

class_name AiAssistantPanel
extends Control

signal open_settings

const AgentController = preload("res://scripts/ai/agent.gd")
const AnthropicClient = preload("res://scripts/ai/anthropic_client.gd")

var _status_label: Label
var _chat_scroll: ScrollContainer
var _chat_log: VBoxContainer
var _input: TextEdit
var _send_btn: Button

var _history: Array = []
var _running: bool = false
var _connected: bool = false
var _start_time: float = 0.0
var _pending_prompt: String = ""
var _pending_history: Array = []
var _test_key: String = ""
var _test_base_url: String = ""
var _test_model: String = ""


func _ready() -> void:
	_setup_ui()
	refresh_connection()


func _process(_delta: float) -> void:
	if _running:
		var elapsed := Time.get_ticks_msec() / 1000.0 - _start_time
		_status_label.text = "Working… %ds" % int(elapsed)


func _setup_ui() -> void:
	var win = UiPanel.new().setup("AI Assistant")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)
	var body: VBoxContainer = win.body()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiTheme.space("s"))
	body.add_child(header)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.custom_minimum_size.x = 0
	header.add_child(_status_label)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.pressed.connect(func() -> void: open_settings.emit())
	header.add_child(settings_btn)

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
	pass


func refresh_connection() -> void:
	var ai := SettingsStore.resolve_ai()
	if str(ai["api_key"]).is_empty():
		_connected = false
		_set_status("Not connected — open Settings to configure", "error")
		return
	_test_key = ai["api_key"]
	_test_base_url = ai["base_url"]
	_test_model = ai["model"]
	_set_status("Testing connection…", "text_muted")
	RChainService.run(_run_connection_test, _on_test_done)


func _run_connection_test() -> Dictionary:
	var c := AnthropicClient.new()
	c.configure(_test_key, _test_base_url, _test_model)
	return c.test_connection()


func _on_test_done(result) -> void:
	if result == null:
		_connected = false
		_set_status("Connection failed: worker returned nothing", "error")
		return
	if not result.get("ok", false):
		_connected = false
		_set_status("Connection failed: " + str(result.get("error", "request failed")), "error")
		return
	_connected = true
	_set_status("Connected (" + str(result.get("model", "Claude")) + ")", "success")


func _on_send() -> void:
	if _running:
		return
	if not _connected:
		_append(UiLabel.Kind.BODY, UiLabel.Tone.ERROR, "Not connected — open Settings to configure.")
		return
	var prompt := _input.text.strip_edges()
	if prompt.is_empty():
		return
	_append(UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY, "You: " + prompt)
	_running = true
	_send_btn.disabled = true
	_start_time = Time.get_ticks_msec() / 1000.0
	_set_status("Working…", "text_muted")

	_pending_prompt = prompt
	_pending_history = _history.duplicate()
	RChainService.run(_run_agent, _on_run_done)


func _run_agent() -> Dictionary:
	var agent := AgentController.new()
	return agent.run(_pending_prompt, _pending_history)


func _on_run_done(result) -> void:
	_running = false
	_send_btn.disabled = false
	if result == null:
		_set_status("Failed: worker returned nothing (crashed?)", "error")
		_append(UiLabel.Kind.BODY, UiLabel.Tone.ERROR, "Error: worker returned nothing (crashed?)")
		return
	if not result.get("ok", false):
		_set_status("Failed: " + str(result.get("error", "request failed")), "error")
		_append(UiLabel.Kind.BODY, UiLabel.Tone.ERROR, "Error: " + str(result.get("error", "request failed")))
		return
	_input.text = ""
	_set_status("Done", "success")
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


func _set_status(text: String, color_token: String) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", UiTheme.color(color_token))
