extends Node
## Autoload singleton owning one shared RNode connection and one identity.
## Access via RChainService.node / RChainService.wallet / RChainService.sdk / RChainService.bridge.

var node: RNodeClient
var wallet: RChainWallet
var sdk: RholangSDK
var bridge: SignalBridge

var _pending: Dictionary = {}  # Thread -> on_done Callable


func _ready() -> void:
	node = RNodeClient.new()
	sdk = RholangSDK.new()
	wallet = RChainWallet.new()
	wallet.set_node(node)
	wallet.set_sdk(sdk)

	bridge = SignalBridge.new()
	add_child(bridge)
	bridge.setup(node, sdk, wallet)


## Run a blocking callable in a background thread; `on_done(result)` fires on the main thread.
func run_async(action: Callable, on_done: Callable) -> void:
	var thread := Thread.new()
	thread.start(action)
	_pending[thread] = on_done


func _process(_delta: float) -> void:
	if _pending.is_empty():
		return
	var done: Array = []
	for thread in _pending.keys():
		if not thread.is_alive():
			done.append(thread)
	for thread in done:
		var result = thread.wait_to_finish()
		var on_done: Callable = _pending[thread]
		_pending.erase(thread)
		on_done.call(result)
