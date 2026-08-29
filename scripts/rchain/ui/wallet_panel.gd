class_name WalletPanel
extends Control
## Key-managed RChain wallet: create/unlock a password-protected keystore,
## show address + balance, transfer, faucet, and a deploy/explore console.
## No plaintext private-key field by default.

var _address_label: Label
var _balance_label: Label
var _status: Label
var _password: LineEdit
var _to_input: LineEdit
var _amount: SpinBox
var _priv_input: LineEdit
var _term: TextEdit
var _output: TextEdit
var _create_btn: Button
var _unlock_btn: Button
var _lock_btn: Button
var _import_btn: Button
var _mnemonic_label: Label
var _mnemonic_input: LineEdit
var _wallet_actions: VBoxContainer
var _overlay: LoadingOverlay = null


func _ready() -> void:
	_setup_ui()
	_ensure_identity()


func _setup_ui() -> void:
	var win := UiPanel.new().setup("RChain Wallet")
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(win)

	var v: VBoxContainer = win.body()

	_status = UiLabel.new().setup("", UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
	win.title_actions().add_child(_status)

	v.add_child(UiSeparator.new())

	# Identity
	_address_label = UiLabel.new().setup("Address: -", UiLabel.Kind.BODY, UiLabel.Tone.PRIMARY)
	_address_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_address_label)
	_balance_label = UiLabel.new().setup("Balance: -", UiLabel.Kind.BODY, UiLabel.Tone.MUTED)
	v.add_child(_balance_label)

	var bal_row := HBoxContainer.new()
	v.add_child(bal_row)
	var bal_btn := UiButton.new().setup("Refresh Balance", UiButton.Variant.SECONDARY)
	bal_btn.pressed.connect(_on_refresh_balance)
	bal_row.add_child(bal_btn)
	var faucet_btn := UiButton.new().setup("Faucet", UiButton.Variant.SECONDARY)
	faucet_btn.pressed.connect(_on_faucet)
	bal_row.add_child(faucet_btn)

	v.add_child(UiSeparator.new())

	# Key management
	v.add_child(UiSection.new().setup("Key management"))
	_password = LineEdit.new()
	_password.placeholder_text = "password (min 6 chars)"
	_password.secret = true
	v.add_child(_password)

	var key_row := HBoxContainer.new()
	v.add_child(key_row)
	_create_btn = UiButton.new().setup("Create", UiButton.Variant.SECONDARY)
	_create_btn.pressed.connect(_on_create)
	key_row.add_child(_create_btn)
	_unlock_btn = UiButton.new().setup("Unlock", UiButton.Variant.PRIMARY)
	_unlock_btn.pressed.connect(_on_unlock)
	key_row.add_child(_unlock_btn)
	_lock_btn = UiButton.new().setup("Lock", UiButton.Variant.SECONDARY)
	_lock_btn.pressed.connect(_on_lock)
	key_row.add_child(_lock_btn)

	# Advanced import (collapsed by default)
	var adv_toggle := Button.new()
	adv_toggle.text = "Import private key…"
	adv_toggle.flat = true
	adv_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	adv_toggle.pressed.connect(_on_import_toggle)
	v.add_child(adv_toggle)
	var adv_row := HBoxContainer.new()
	adv_row.name = "ImportRow"
	adv_row.visible = false
	v.add_child(adv_row)
	_priv_input = LineEdit.new()
	_priv_input.placeholder_text = "private key hex (advanced)"
	_priv_input.secret = true
	_priv_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adv_row.add_child(_priv_input)
	_import_btn = UiButton.new().setup("Import", UiButton.Variant.SECONDARY)
	_import_btn.pressed.connect(_on_import)
	adv_row.add_child(_import_btn)

	# Import mnemonic (collapsed by default)
	var mnem_toggle := Button.new()
	mnem_toggle.text = "Import mnemonic phrase…"
	mnem_toggle.flat = true
	mnem_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mnem_toggle.pressed.connect(_on_mnemonic_import_toggle)
	v.add_child(mnem_toggle)
	var mnem_row := HBoxContainer.new()
	mnem_row.name = "MnemonicRow"
	mnem_row.visible = false
	v.add_child(mnem_row)
	_mnemonic_input = LineEdit.new()
	_mnemonic_input.placeholder_text = "24-word recovery phrase"
	_mnemonic_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mnem_row.add_child(_mnemonic_input)
	var mnem_import_btn := UiButton.new().setup("Import", UiButton.Variant.SECONDARY)
	mnem_import_btn.pressed.connect(_on_import_mnemonic)
	mnem_row.add_child(mnem_import_btn)

	# Recovery phrase (shown after create)
	v.add_child(UiSection.new().setup("Recovery phrase"))
	_mnemonic_label = UiLabel.new().setup("", UiLabel.Kind.BODY, UiLabel.Tone.WARNING)
	_mnemonic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_mnemonic_label)

	# Fund operations — only shown when unlocked.
	_wallet_actions = VBoxContainer.new()
	_wallet_actions.add_theme_constant_override("separation", UiTheme.space("s"))
	_wallet_actions.visible = false
	v.add_child(_wallet_actions)

	# Transfer
	_wallet_actions.add_child(UiSection.new().setup("Transfer"))
	var tx_row := HBoxContainer.new()
	_wallet_actions.add_child(tx_row)
	_to_input = LineEdit.new()
	_to_input.placeholder_text = "to REV address"
	_to_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx_row.add_child(_to_input)
	_amount = SpinBox.new()
	_amount.min_value = 0
	_amount.max_value = 1000000000
	tx_row.add_child(_amount)
	var send_btn := UiButton.new().setup("Transfer", UiButton.Variant.SECONDARY)
	send_btn.pressed.connect(_on_transfer)
	tx_row.add_child(send_btn)

	# Deploy / Explore console
	_wallet_actions.add_child(UiSection.new().setup("Deploy / Explore"))
	_term = TextEdit.new()
	_term.custom_minimum_size.y = 70
	_term.placeholder_text = "rholang term"
	_wallet_actions.add_child(_term)
	var term_row := HBoxContainer.new()
	_wallet_actions.add_child(term_row)
	var deploy_btn := UiButton.new().setup("Deploy", UiButton.Variant.SECONDARY)
	deploy_btn.pressed.connect(_on_deploy)
	term_row.add_child(deploy_btn)
	var explore_btn := UiButton.new().setup("Explore", UiButton.Variant.SECONDARY)
	explore_btn.pressed.connect(_on_explore)
	term_row.add_child(explore_btn)

	_output = TextEdit.new()
	_output.custom_minimum_size.y = 100
	_output.editable = false
	_wallet_actions.add_child(_output)


func _ensure_identity() -> void:
	var w: RChainWallet = RChainService.wallet
	if w.has_keystore():
		w.lock()
	else:
		if not w.is_ready():
			w.generate()
	_refresh()


func _refresh() -> void:
	var w: RChainWallet = RChainService.wallet
	if _wallet_actions:
		_wallet_actions.visible = w.is_ready()
	if w.is_ready():
		_address_label.text = "Address: " + w.get_rev_address()
		_status.text = "unlocked"
		_create_btn.disabled = false
		_unlock_btn.disabled = true
		_lock_btn.disabled = false
	else:
		_address_label.text = "Address: (locked)"
		_status.text = "locked"
		_create_btn.disabled = false
		_unlock_btn.disabled = not w.has_keystore()
		_lock_btn.disabled = true


func _on_create() -> void:
	var pw := _password.text
	if pw.length() < 6:
		_status.text = "Password must be 6+ characters"
		return
	var w: RChainWallet = RChainService.wallet
	var gen := w.generate_mnemonic()
	if gen.is_err():
		_status.text = "Error: " + gen.get_error()
		return
	var mnemonic: String = gen.get_data().get("mnemonic", "")
	var r := w.save_keystore(pw)
	_status.text = "Saved" if r.is_ok() else r.get_error()
	_mnemonic_label.text = mnemonic
	_refresh()


func _on_unlock() -> void:
	var r := RChainService.wallet.unlock(_password.text)
	_status.text = "Unlocked" if r.is_ok() else r.get_error()
	_refresh()


func _on_lock() -> void:
	RChainService.wallet.lock()
	_refresh()


func _on_import_toggle() -> void:
	var row := find_child("ImportRow", true, false)
	if row:
		row.visible = not row.visible


func _on_import() -> void:
	var r := RChainService.wallet.from_private_key(_priv_input.text.strip_edges())
	_status.text = "Imported" if r.is_ok() else r.get_error()
	_refresh()


func _on_import_mnemonic() -> void:
	var mnemonic := _mnemonic_input.text.strip_edges()
	if not RChainCrypto.is_valid_mnemonic(mnemonic):
		_status.text = "Invalid mnemonic phrase"
		return
	var r := RChainService.wallet.from_mnemonic(mnemonic)
	_status.text = "Imported" if r.is_ok() else r.get_error()
	_refresh()


func _on_mnemonic_import_toggle() -> void:
	var row := find_child("MnemonicRow", true, false)
	if row:
		row.visible = not row.visible


func _on_refresh_balance() -> void:
	var w: RChainWallet = RChainService.wallet
	if not w.is_ready():
		_balance_label.text = "Balance: —"
		return
	_run_with_loading(func() -> Variant: return w.check_balance(), func(r: Result) -> void:
		if r.is_err():
			_balance_label.text = "Balance: (offline) " + r.get_error()
		else:
			var exprs: Array = r.get_data()
			var balance := 0
			if not exprs.is_empty():
				balance = int(RChainService.sdk.rho_expr_to_json(exprs[0]))
			_balance_label.text = "Balance: %d REV" % balance
	, "Checking balance...")


func _on_faucet() -> void:
	var w: RChainWallet = RChainService.wallet
	if not w.is_ready():
		_status.text = "Unlock or create a wallet first"
		return
	var addr: String = w.get_rev_address()
	_run_with_loading(func() -> Variant: return RChainService.node.faucet(addr), func(r: Result) -> void:
		_status.text = "Faucet: " + ("ok" if r.is_ok() else r.get_error())
		_refresh()
	, "Funding...")


func _on_transfer() -> void:
	var w: RChainWallet = RChainService.wallet
	if not w.is_ready():
		_status.text = "Unlock or create a wallet first"
		return
	var to: String = _to_input.text.strip_edges()
	if not RChainCrypto.is_valid_rev_address(to):
		_status.text = "Invalid REV address"
		return
	var amount: int = int(_amount.value)
	_run_with_loading(func() -> Variant: return w.transfer(to, amount), func(r: Result) -> void:
		_status.text = "Transfer: " + ("ok" if r.is_ok() else r.get_error())
	, "Transferring...")


func _on_deploy() -> void:
	var w: RChainWallet = RChainService.wallet
	if not w.is_ready():
		_status.text = "Unlock or create a wallet first"
		return
	var term: String = _term.text
	_run_with_loading(func() -> Variant:
		var status: Result = RChainService.node.get_status()
		if status.is_err():
			return status
		var signed: Result = w.sign_deploy(term, status.get_data())
		if signed.is_err():
			return signed
		return RChainService.node.deploy(signed.get_data())
	, func(r: Result) -> void:
		if r.is_ok():
			_output.text = JSON.stringify(r.get_data(), "  ")
			_status.text = "Deployed"
		else:
			_status.text = "Deploy error: " + r.get_error()
	, "Deploying...")


func _on_explore() -> void:
	var term: String = _term.text
	_run_with_loading(func() -> Variant: return RChainService.node.explore_deploy(term), func(r: Result) -> void:
		if r.is_ok():
			_output.text = JSON.stringify(r.get_data(), "  ")
			_status.text = "Explored"
		else:
			_status.text = "Explore error: " + r.get_error()
	, "Exploring...")


func _run_with_loading(action: Callable, on_done: Callable, message: String) -> void:
	_overlay = LoadingOverlay.show_overlay(self, message)
	var wrapped := func(result) -> void:
		_dismiss_overlay()
		on_done.call(result)
	RChainService.run_async(action, wrapped)


func _dismiss_overlay() -> void:
	if _overlay:
		_overlay.dismiss()
		_overlay = null
