class_name SignalBridge
extends Node
## Adapter between Godot signals and rholang channels (docs/rchain/coordination-model.md).
## emit() deploys a channel send; a poll loop diffs data-at-name and emits channel_data.

signal channel_data(channel: String, data: Variant)

var _node: RNodeClient = null
var _sdk: RholangSDK = null
var _wallet: RChainWallet = null

var _channels: Dictionary = {}  # channel_name -> last_seen (Array of normalized values)
var _poll_timer: Timer = null
var _poll_interval: float = 1.0


func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = _poll_interval
	_poll_timer.timeout.connect(poll)
	add_child(_poll_timer)
	_poll_timer.start()


func setup(node: RNodeClient, sdk: RholangSDK, wallet: RChainWallet) -> void:
	_node = node
	_sdk = sdk
	_wallet = wallet


## Subscribe to a rholang channel; new data will emit channel_data(channel, data).
func register_channel(channel_name: String) -> void:
	if not _channels.has(channel_name):
		_channels[channel_name] = []


func emit(channel: String, data: Dictionary) -> Result:
	if _wallet == null or _sdk == null:
		return Result.err("bridge not connected")
	var term := _sdk.build_emit(channel, data)
	return _wallet.deploy_term(term)


## Poll all subscribed channels for new data.
func poll() -> void:
	if _node == null or _sdk == null:
		return
	for channel in _channels.keys():
		var name_rho := _sdk.name_to_rho(str(channel))
		var r := _node.data_at_name(name_rho, 1)
		if r.is_err():
			continue
		var exprs: Array = r.get_data().get("exprs", [])
		var normalized: Array = []
		for e in exprs:
			normalized.append(_sdk.rho_expr_to_json(e))
		if not _same(normalized, _channels[channel]):
			_channels[channel] = normalized
			for value in normalized:
				channel_data.emit(str(channel), value)


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if JSON.stringify(a[i]) != JSON.stringify(b[i]):
			return false
	return true
