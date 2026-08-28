class_name SignalBridge
extends Node
## Adapter between Godot signals and rholang channels (docs/rchain/coordination-model.md).
## emit() deploys a channel send; a background poll loop diffs data-at-name and emits
## channel_data on the main thread (via call_deferred).

signal channel_data(channel: String, data: Variant)

var _node: RNodeClient = null
var _sdk: RholangSDK = null
var _wallet: RChainWallet = null

var _channels: Dictionary = {}  # channel_name -> last_seen (Array of normalized values)
var _mutex: Mutex = Mutex.new()
var _poll_thread: Thread = null
var _running: bool = false
var _poll_interval: float = 1.0


func _ready() -> void:
	_running = true
	_poll_thread = Thread.new()
	_poll_thread.start(_poll_loop)


func _exit_tree() -> void:
	_running = false
	if _poll_thread and _poll_thread.is_alive():
		_poll_thread.wait_to_finish()


func setup(node: RNodeClient, sdk: RholangSDK, wallet: RChainWallet) -> void:
	_node = node
	_sdk = sdk
	_wallet = wallet


## Subscribe to a rholang channel; new data will emit channel_data(channel, data).
func register_channel(channel_name: String) -> void:
	_mutex.lock()
	if not _channels.has(channel_name):
		_channels[channel_name] = []
	_mutex.unlock()


func emit(channel: String, data: Dictionary) -> Result:
	if _wallet == null or _sdk == null:
		return Result.err("bridge not connected")
	var term := _sdk.build_emit(channel, data)
	return _wallet.deploy_term(term)


## Poll all subscribed channels for new data (runs on the background thread).
func _poll_loop() -> void:
	while _running:
		_poll_once()
		OS.delay_msec(int(_poll_interval * 1000.0))


func _poll_once() -> void:
	if _node == null or _sdk == null:
		return
	var to_emit: Array = []
	for channel in _channel_names():
		var name_rho := _sdk.name_to_rho(str(channel))
		var r := _node.data_at_name(name_rho, 1)
		if r.is_err():
			continue
		var exprs: Array = r.get_data().get("exprs", [])
		var normalized: Array = []
		for e in exprs:
			normalized.append(_sdk.rho_expr_to_json(e))
		if not _same(normalized, _get_channel(channel)):
			_set_channel(channel, normalized)
			for value in normalized:
				to_emit.append({"channel": str(channel), "value": value})
	for item in to_emit:
		call_deferred("_emit_data", item["channel"], item["value"])


func _emit_data(channel: String, value: Variant) -> void:
	channel_data.emit(channel, value)


func _channel_names() -> Array:
	_mutex.lock()
	var keys := _channels.keys()
	_mutex.unlock()
	return keys


func _get_channel(channel: String) -> Array:
	_mutex.lock()
	var v = _channels.get(channel, [])
	_mutex.unlock()
	return v


func _set_channel(channel: String, value: Array) -> void:
	_mutex.lock()
	_channels[channel] = value
	_mutex.unlock()


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if JSON.stringify(a[i]) != JSON.stringify(b[i]):
			return false
	return true
