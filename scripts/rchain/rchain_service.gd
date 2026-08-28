extends Node
## Autoload singleton owning one shared RNode connection and one identity.
## Access via RChainService.node / RChainService.wallet / RChainService.sdk / RChainService.bridge.

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
	bridge.setup(node, sdk, wallet)
