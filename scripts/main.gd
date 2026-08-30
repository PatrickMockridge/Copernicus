# main.gd
# Agentic AI assistant panel. Claude (Anthropic, tool-use) reads and edits a
# user workspace directly. The connection is *tested* with a real round-trip,
# and the endpoint (base URL) + model are configurable in the panel — different
# Anthropic-compatible providers have different endpoints, not just keys.

class_name AiAssistantPanel
extends Control

const AgentController = preload("res://scripts/ai/agent.gd")
const AnthropicClient = preload("res://scripts/ai/anthropic_client.gd")
const CONFIG_PATH := "user://ai_config.json"
const DEFAULT_BASE_URL := "https://api.anthropic.com"
const DEFAULT_MODEL := "claude-sonnet-4-6"

var _key_input: LineEdit
var _base_url_input: LineEdit
var _model_input: LineEdit
var _connect_btn: Button
var _status_label: Label
var _chat_scroll: ScrollContainer
var _chat_log: VBoxContainer
var _input: TextEdit
var _send_btn: Button

var _persisted: Dictionary = {}
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
	_persisted = _load_persisted_config()
	_setup_ui()
	_auto_connect()


func _process(_delta: float) -> void:
	if _running:
		var elapsed := Time.get_ticks_msec() / 1000.0 - _start_time
		_status_label.text = "Working… %ds" % int(elapsed)


func _setup_ui() -> void:
	var win = UiPanel.new().setup("AI Assistant")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)
	var body: VBoxContainer = win.body()

	# Connection header.
	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", UiTheme.space("s"))
	body.add_child(key_row)

	_key_input = LineEdit.new()
	_key_input.placeholder_text = "API key (sk-ant-…)"
	_key_input.secret = true
	_key_input.custom_minimum_size.x = 0
	_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(_key_input)

	_connect_btn = Button.new()
	_connect_btn.text = "Connect"
	_connect_btn.pressed.connect(_on_connect)
	key_row.add_child(_connect_btn)

	_base_url_input = LineEdit.new()
	_base_url_input.placeholder_text = DEFAULT_BASE_URL
	_base_url_input.custom_minimum_size.x = 0
	_base_url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_base_url_input.text = EnvService.get_var("ANTHROPIC_BASE_URL")
	body.add_child(_base_url_input)

	_model_input = LineEdit.new()
	_model_input.placeholder_text = DEFAULT_MODEL
	_model_input.custom_minimum_size.x = 0
	_model_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_input.text = EnvService.get_var("ANTHROPIC_MODEL")
	body.add_child(_model_input)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.custom_minimum_size.x = 0
	body.add_child(_status_label)

	# Chat.
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_chat_scroll)
	_chat_log = VBoxContainer.new()
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_constant_override("separation", UiTheme.space("s"))
	_chat_scroll.add_child(_chat_log)

	# Input + actions.
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


# ---------------------------------------------------------------- connection

func _auto_connect() -> void:
	var key := EnvService.get_anthropic_key()
	if key.is_empty():
		key = str(_persisted.get("api_key", ""))
	if key.is_empty():
		_set_status("Not connected — enter an API key and press Connect", "error")
		_key_input.grab_focus()
		return
	_test_connection(key, _resolve_base_url(), _resolve_model())


func _on_connect() -> void:
	var key := _key_input.text.strip_edges()
	if key.is_empty():
		key = EnvService.get_anthropic_key()
	if key.is_empty():
		key = str(_persisted.get("api_key", ""))
	if key.is_empty():
		_set_status("Enter an API key", "error")
		return
	_test_connection(key, _resolve_base_url(), _resolve_model())


func _resolve_base_url() -> String:
	var v := _base_url_input.text.strip_edges()
	if not v.is_empty():
		return v
	v = EnvService.get_var("ANTHROPIC_BASE_URL")
	if not v.is_empty():
		return v
	v = str(_persisted.get("base_url", ""))
	if not v.is_empty():
		return v
	return DEFAULT_BASE_URL


func _resolve_model() -> String:
	var v := _model_input.text.strip_edges()
	if not v.is_empty():
		return v
	v = EnvService.get_var("ANTHROPIC_MODEL")
	if not v.is_empty():
		return v
	v = str(_persisted.get("model", ""))
	if not v.is_empty():
		return v
	return DEFAULT_MODEL


func _test_connection(key: String, base_url: String, model: String) -> void:
	_set_status("Testing connection…", "text_muted")
	_connect_btn.disabled = true
	_test_key = key
	_test_base_url = base_url
	_test_model = model
	RChainService.run(_run_connection_test, _on_test_done)


func _run_connection_test() -> Dictionary:
	var c := AnthropicClient.new()
	c.configure(_test_key, _test_base_url, _test_model)
	return c.test_connection()


func _on_test_done(result) -> void:
	_connect_btn.disabled = false
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
	# Persist a manually-entered config (don't duplicate .env).
	if not _key_input.text.strip_edges().is_empty() and EnvService.get_anthropic_key().is_empty():
		_save_persisted_config({"api_key": _test_key, "base_url": _test_base_url, "model": _test_model})


func _load_persisted_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _save_persisted_config(cfg: Dictionary) -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cfg))


func _set_status(text: String, color_token: String) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", UiTheme.color(color_token))


# ---------------------------------------------------------------- send / run

func _on_send() -> void:
	if _running:
		return
	if not _connected:
		_append(UiLabel.Kind.BODY, UiLabel.Tone.ERROR, "Not connected — enter an API key and press Connect.")
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
