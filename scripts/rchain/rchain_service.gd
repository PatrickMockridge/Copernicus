extends Node
## Autoload singleton owning one shared RNode connection and one identity.
## Access via RChainService.node / RChainService.wallet / RChainService.sdk / RChainService.bridge.

var node: RNodeClient
var wallet: RChainWallet
var sdk: RholangSDK
var bridge: SignalBridge

const MAX_THREADS := 16

var _pending: Dictionary = {}  # Thread -> on_done Callable
var _queue: Array = []  # [{action, on_done}] waiting for a free slot


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
	if _pending.size() >= MAX_THREADS:
		_queue.append({"action": action, "on_done": on_done})
		return
	_start_thread(action, on_done)


func _start_thread(action: Callable, on_done: Callable) -> void:
	var thread := Thread.new()
	var err := thread.start(action)
	if err != OK:
		push_error("RChainService: thread start failed (%d)" % err)
		on_done.call(null)
		return
	_pending[thread] = on_done


func _process(_delta: float) -> void:
	# Collect finished threads and surface their results on the main thread.
	if not _pending.is_empty():
		var done: Array = []
		for thread in _pending.keys():
			if not thread.is_alive():
				done.append(thread)
		for thread in done:
			var result = thread.wait_to_finish()
			var on_done: Callable = _pending[thread]
			_pending.erase(thread)
			on_done.call(result)
	# Drain queued work now that slots may be free.
	while _pending.size() < MAX_THREADS and not _queue.is_empty():
		var task: Dictionary = _queue.pop_front()
		_start_thread(task["action"], task["on_done"])


func _exit_tree() -> void:
	# Wait for in-flight threads (bounded by the RNode HTTP timeouts) so they don't
	# outlive this node during shutdown.
	for thread in _pending.keys():
		if thread.is_alive():
			thread.wait_to_finish()
	_pending.clear()
	_queue.clear()
