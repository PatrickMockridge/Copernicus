# settings_panel.gd
# The Settings screen: where the user sets the AI key, endpoint, model, and
# workspace (and future settings). Saves to the shared SettingsStore and can
# test the connection with a real round-trip.

class_name SettingsPanel
extends Control

signal saved

const AnthropicClient = preload("res://scripts/ai/anthropic_client.gd")

var _key_input: LineEdit
var _base_url_input: LineEdit
var _model_input: LineEdit
var _workspace_input: LineEdit
var _status_label: Label
var _test_btn: Button
var _priv_input: LineEdit
var _mnemonic_input: LineEdit
var _wallet_status: Label

var _test_key: String = ""
var _test_base_url: String = ""
var _test_model: String = ""


func _ready() -> void:
	_setup_ui()
	_load_into_fields()
	_refresh_wallet_status()


func _setup_ui() -> void:
	var win = UiPanel.new().setup("Settings")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)
	var body: VBoxContainer = win.body()

	body.add_child(UiLabel.new().setup("AI / Connection", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED))

	_key_input = _add_field(body, "API key", "sk-ant-…", true)
	_base_url_input = _add_field(body, "Base URL", "https://api.anthropic.com", false)
	_model_input = _add_field(body, "Model", "claude-sonnet-4-6", false)
	_workspace_input = _add_field(body, "Workspace", "~/robot_workspace", false)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.custom_minimum_size.x = 0
	body.add_child(_status_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.space("s"))
	body.add_child(row)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save)
	row.add_child(save_btn)

	_test_btn = Button.new()
	_test_btn.text = "Test connection"
	_test_btn.pressed.connect(_on_test)
	row.add_child(_test_btn)

	# Blockchain wallet
	body.add_child(UiSeparator.new())
	body.add_child(UiLabel.new().setup("Blockchain wallet", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED))

	_wallet_status = Label.new()
	_wallet_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_wallet_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet_status.custom_minimum_size.x = 0
	body.add_child(_wallet_status)

	body.add_child(UiLabel.new().setup("Private key", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED))
	var priv_row := HBoxContainer.new()
	priv_row.add_theme_constant_override("separation", UiTheme.space("s"))
	body.add_child(priv_row)
	_priv_input = LineEdit.new()
	_priv_input.placeholder_text = "private key hex"
	_priv_input.secret = true
	_priv_input.custom_minimum_size.x = 0
	_priv_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	priv_row.add_child(_priv_input)
	var priv_btn := Button.new()
	priv_btn.text = "Import"
	priv_btn.pressed.connect(_on_import_private_key)
	priv_row.add_child(priv_btn)

	body.add_child(UiLabel.new().setup("Mnemonic phrase", UiLabel.Kind.SMALL, UiLabel.Tone.MUTED))
	var mnem_row := HBoxContainer.new()
	mnem_row.add_theme_constant_override("separation", UiTheme.space("s"))
	body.add_child(mnem_row)
	_mnemonic_input = LineEdit.new()
	_mnemonic_input.placeholder_text = "24-word recovery phrase"
	_mnemonic_input.custom_minimum_size.x = 0
	_mnemonic_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mnem_row.add_child(_mnemonic_input)
	var mnem_btn := Button.new()
	mnem_btn.text = "Import"
	mnem_btn.pressed.connect(_on_import_mnemonic)
	mnem_row.add_child(mnem_btn)


func _add_field(parent: Control, label_text: String, placeholder: String, secret: bool) -> LineEdit:
	parent.add_child(UiLabel.new().setup(label_text, UiLabel.Kind.SMALL, UiLabel.Tone.MUTED))
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size.x = 0
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(e)
	return e


func _load_into_fields() -> void:
	var ai := SettingsStore.get_ai()
	_key_input.text = str(ai.get("api_key", ""))
	_base_url_input.text = str(ai.get("base_url", ""))
	_model_input.text = str(ai.get("model", ""))
	_workspace_input.text = str(ai.get("workspace", ""))


func _on_save() -> void:
	SettingsStore.set_ai({
		"api_key": _key_input.text.strip_edges(),
		"base_url": _base_url_input.text.strip_edges(),
		"model": _model_input.text.strip_edges(),
		"workspace": _workspace_input.text.strip_edges(),
	})
	_set_status("Saved", "success")
	saved.emit()


func _on_test() -> void:
	var key := _key_input.text.strip_edges()
	if key.is_empty():
		_set_status("Enter an API key first", "error")
		return
	_test_key = key
	_test_base_url = _base_url_input.text.strip_edges()
	_test_model = _model_input.text.strip_edges()
	_set_status("Testing…", "text_muted")
	_test_btn.disabled = true
	RChainService.run(_run_test, _on_test_done)


func _run_test() -> Dictionary:
	var c := AnthropicClient.new()
	c.configure(_test_key, _test_base_url, _test_model)
	return c.test_connection()


func _on_test_done(result) -> void:
	_test_btn.disabled = false
	if result == null:
		_set_status("Test failed: worker returned nothing", "error")
		return
	if not result.get("ok", false):
		_set_status("Test failed: " + str(result.get("error", "request failed")), "error")
		return
	_set_status("Connected (" + str(result.get("model", "Claude")) + ")", "success")


func _set_status(text: String, color_token: String) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", UiTheme.color(color_token))


func _set_wallet_status(text: String, color_token: String) -> void:
	_wallet_status.text = text
	_wallet_status.add_theme_color_override("font_color", UiTheme.color(color_token))


func _refresh_wallet_status() -> void:
	var addr := RChainService.wallet.get_address()
	if addr.is_empty():
		_set_wallet_status("No wallet imported", "text_muted")
	else:
		_set_wallet_status("Address: " + addr, "success")


func _on_import_private_key() -> void:
	var hex := _priv_input.text.strip_edges()
	if hex.is_empty():
		_set_wallet_status("Enter a private key", "error")
		return
	var r := RChainService.wallet.from_private_key(hex)
	if r.is_ok():
		_priv_input.text = ""
		_refresh_wallet_status()
	else:
		_set_wallet_status(r.get_error(), "error")


func _on_import_mnemonic() -> void:
	var mnemonic := _mnemonic_input.text.strip_edges()
	if mnemonic.is_empty():
		_set_wallet_status("Enter a mnemonic phrase", "error")
		return
	if not RChainCrypto.is_valid_mnemonic(mnemonic):
		_set_wallet_status("Invalid mnemonic phrase", "error")
		return
	var r := RChainService.wallet.from_mnemonic(mnemonic)
	if r.is_ok():
		_mnemonic_input.text = ""
		_refresh_wallet_status()
	else:
		_set_wallet_status(r.get_error(), "error")
