extends TaskRunner
## Autoload singleton owning one shared RNode connection and one identity, plus
## the single background-task runner (TaskRunner). Access via
## RChainService.node / .wallet / .sdk / .bridge.

var node: RNodeClient
var wallet: RChainWallet
var sdk: RholangSDK
var bridge: SignalBridge


func _ready() -> void:
	node = RNodeClient.new()
	sdk = RholangSDK.new()
	wallet = RChainWallet.new()
	wallet.set_node(node)
	wallet.set_sdk(sdk)

	bridge = SignalBridge.new()
	add_child(bridge)
	bridge.setup(node, sdk, wallet, self)


## Alias for TaskRunner.run — kept for the existing call sites.
func run_async(action: Callable, on_done: Callable) -> void:
	run(action, on_done)
