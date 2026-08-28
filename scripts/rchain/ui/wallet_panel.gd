class_name WalletPanel
extends Control
## In-app RChain wallet: keygen/import, address+balance, transfer, deploy/explore console.

var _address_label: Label
var _balance_label: Label
var _status: Label
var _priv_input: LineEdit
var _to_input: LineEdit
var _amount: SpinBox
var _term: TextEdit
var _output: TextEdit
var _overlay: LoadingOverlay = null


func _ready() -> void:
	_setup_ui()
	_refresh()


func _setup_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	CopernicusTheme.style_panel(panel)
	add_child(panel)

	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_theme_constant_override("separation", 8)

	v.add_child(CopernicusTheme.make_heading("RChain Wallet"))

	# identity
	var id_row := HBoxContainer.new()
	v.add_child(id_row)
	var gen_btn := Button.new()
	gen_btn.text = "Generate Key"
	gen_btn.pressed.connect(_on_generate)
	id_row.add_child(gen_btn)
	_priv_input = LineEdit.new()
	_priv_input.placeholder_text = "private key hex (import)"
	_priv_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_row.add_child(_priv_input)
	var import_btn := Button.new()
	import_btn.text = "Import"
	import_btn.pressed.connect(_on_import)
	id_row.add_child(import_btn)

	# address + balance
	_address_label = CopernicusTheme.make_body("Address: -")
	_address_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_address_label)
	_balance_label = CopernicusTheme.make_body("Balance: -")
	v.add_child(_balance_label)

	var bal_row := HBoxContainer.new()
	v.add_child(bal_row)
	var bal_btn := Button.new()
	bal_btn.text = "Refresh Balance"
	bal_btn.pressed.connect(_on_refresh_balance)
	bal_row.add_child(bal_btn)
	var faucet_btn := Button.new()
	faucet_btn.text = "Faucet"
	faucet_btn.pressed.connect(_on_faucet)
	bal_row.add_child(faucet_btn)

	v.add_child(CopernicusTheme.make_separator())

	# transfer
	var tx_row := HBoxContainer.new()
	v.add_child(tx_row)
	_to_input = LineEdit.new()
	_to_input.placeholder_text = "to REV address"
	_to_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx_row.add_child(_to_input)
	_amount = SpinBox.new()
	_amount.min_value = 0
	_amount.max_value = 1000000000
	tx_row.add_child(_amount)
	var send_btn := Button.new()
	send_btn.text = "Transfer"
	send_btn.pressed.connect(_on_transfer)
	tx_row.add_child(send_btn)

	v.add_child(CopernicusTheme.make_separator())

	# term console
	v.add_child(CopernicusTheme.make_heading("Deploy / Explore"))
	_term = TextEdit.new()
	_term.custom_minimum_size.y = 80
	_term.placeholder_text = "rholang term"
	v.add_child(_term)
	var term_row := HBoxContainer.new()
	v.add_child(term_row)
	var deploy_btn := Button.new()
	deploy_btn.text = "Deploy"
	deploy_btn.pressed.connect(_on_deploy)
	term_row.add_child(deploy_btn)
	var explore_btn := Button.new()
	explore_btn.text = "Explore"
	explore_btn.pressed.connect(_on_explore)
	term_row.add_child(explore_btn)

	_output = TextEdit.new()
	_output.custom_minimum_size.y = 120
	_output.editable = false
	v.add_child(_output)

	_status = CopernicusTheme.make_body("")
	v.add_child(_status)


func _refresh() -> void:
	var w: RChainWallet = RChainService.wallet
	if w.is_ready():
		_address_label.text = "Address: " + w.get_rev_address()
	else:
		_address_label.text = "Address: (no key)"


func _on_generate() -> void:
	var r: Result = RChainService.wallet.generate()
	if r.is_err():
		_status.text = "Error: " + r.get_error()
	else:
		_status.text = "Generated " + RChainService.wallet.get_rev_address()
	_refresh()


func _on_import() -> void:
	var r: Result = RChainService.wallet.from_private_key(_priv_input.text.strip_edges())
	if r.is_err():
		_status.text = "Import error: " + r.get_error()
	else:
		_status.text = "Imported " + RChainService.wallet.get_rev_address()
	_refresh()


func _on_refresh_balance() -> void:
	var r: Result = RChainService.wallet.check_balance()
	if r.is_err():
		_balance_label.text = "Balance: (error) " + r.get_error()
	else:
		var exprs: Array = r.get_data()
		var balance := 0
		if not exprs.is_empty():
			balance = int(RChainService.sdk.rho_expr_to_json(exprs[0]))
		_balance_label.text = "Balance: %d REV" % balance
	_refresh()


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


func _on_faucet() -> void:
	var addr: String = RChainService.wallet.get_rev_address()
	if addr.is_empty():
		_status.text = "No address; generate/import a key first"
		return
	_run_with_loading(func() -> Variant: return RChainService.node.faucet(addr), func(r: Result) -> void:
		_status.text = "Faucet: " + ("ok" if r.is_ok() else r.get_error())
		_refresh()
	, "Funding...")


func _on_transfer() -> void:
	var to: String = _to_input.text.strip_edges()
	var amount: int = int(_amount.value)
	_run_with_loading(func() -> Variant: return RChainService.wallet.transfer(to, amount), func(r: Result) -> void:
		_status.text = "Transfer: " + ("ok" if r.is_ok() else r.get_error())
	, "Transferring...")


func _on_deploy() -> void:
	var term: String = _term.text
	_run_with_loading(func() -> Variant:
		var status: Result = RChainService.node.get_status()
		if status.is_err():
			return status
		var signed: Result = RChainService.wallet.sign_deploy(term, status.get_data())
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
