# ARIADNE API Reference

Complete API for the ARIADNE blockchain interface.

## AriadneInterface (ariadne_interface.gd)

```gdscript
class_name AriadneInterface
```

Wrapper class for ariadne-cli commands. Executes CLI via `OS.execute()`.

### Initialization

```gdscript
var ariadne = AriadneInterface.new()
```

The class automatically finds `node_modules/ariadne-cli/cli/index.js` relative to the addon.

---

## Methods

### Initialization & Repository

#### `is_initialized() -> bool`
Check if the current git repository has ARIADNE tracking enabled (`.gitariadne` exists).

```gdscript
if ariadne.is_initialized():
    print("Repository is on Arweave")
```

#### `get_repo_id() -> String`
Get the repository ID (manifest transaction ID on Arweave).

```gdscript
var repo_id = ariadne.get_repo_id()
print("Repo ID: ", repo_id)
```

#### `initialize(wallet_path: String = "", create: bool = false, private_repo: bool = false) -> Dictionary`
Initialize ARIADNE tracking or create a new repository.

| Parameter | Type | Description |
|-----------|------|-------------|
| `wallet_path` | String | Path to JWK wallet file |
| `create` | bool | Create new repository on Arweave |
| `private_repo` | bool | Enable encryption |

```gdscript
# Create new public repository
var result = ariadne.initialize("user://wallet.json", true, false)

# Create new private (encrypted) repository
var result = ariadne.initialize("user://wallet.json", true, true)
```

**Returns:** `Dictionary` with `exit_code` (int) and `output` (String).

---

### Push & Pull

#### `push(wallet_path: String = "", private_repo: bool = false) -> Dictionary`
Push commits to Arweave.

```gdscript
var result = ariadne.push("user://wallet.json")
if result["exit_code"] == 0:
    print("Published successfully!")
else:
    print("Error: ", result["output"])
```

#### `pull() -> Dictionary`
Pull commits from Arweave.

```gdscript
var result = ariadne.pull()
```

#### `clone(repo_id: String, wallet_path: String = "") -> Dictionary`
Clone a repository from ARIADNE.

```gdscript
var result = ariadne.clone("x8asj3...", "user://wallet.json")
```

---

### Status & History

#### `get_status() -> Dictionary`
Get the current working tree status.

```gdscript
var status = ariadne.get_status()
# {
#     "branch": "main",
#     "staged": ["file1.gd", "file2.gd"],
#     "modified": ["file3.gd"],
#     "untracked": ["new_file.gd"],
#     "is_clean": false
# }
```

#### `get_log(limit: int = 10) -> Array`
Get commit history.

```gdscript
var commits = ariadne.get_log(10)
for commit in commits:
    print(commit["oid"], commit["author"], commit["message"])
```

---

### Wallet Management

#### `set_default_wallet(path: String) -> void`
Set the default wallet path.

```gdscript
ariadne.set_default_wallet("user://wallet.json")
```

#### `get_default_wallet() -> String`
Get the default wallet path.

```gdscript
var wallet = ariadne.get_default_wallet()
```

---

### Command Output

#### `get_last_output() -> String`
Get the output from the last command.

#### `get_last_exit_code() -> int`
Get the exit code from the last command (0 = success).

---

## WalletManager (wallet_manager.gd)

```gdscript
class_name WalletManager
```

Manages Arweave wallet files.

### Methods

#### `load_wallet(path: String) -> bool`
Load and validate a JWK wallet file.

```gdscript
var wallet = WalletManager.new()
if wallet.load_wallet("user://wallet.json"):
    print("Wallet loaded")
else:
    print("Failed to load wallet")
```

#### `get_address() -> String`
Get the wallet address.

```gdscript
var address = wallet.get_address()
```

#### `get_wallet_path() -> String`
Get the loaded wallet path.

```gdscript
var path = wallet.get_wallet_path()
```

#### `has_wallet() -> bool`
Check if a wallet is loaded.

```gdscript
if wallet.has_wallet():
    print("Wallet ready")
```

#### `find_and_load_wallet() -> bool`
Search common wallet locations and load the first available.

```gdscript
if wallet.find_and_load_wallet():
    print("Found wallet at common location")
```

#### `set_wallet_path(path: String) -> void`
Set wallet path without loading.

#### `clear_wallet() -> void`
Clear the loaded wallet.

---

## Return Value Format

All methods that execute commands return a `Dictionary`:

```gdscript
{
    "exit_code": 0,        # 0 = success, non-zero = error
    "output": "..."        # Command output (stdout or error)
}
```

Check for success:
```gdscript
var result = ariadne.push()
if result["exit_code"] == 0:
    print("Success: ", result["output"])
else:
    print("Error: ", result["output"])
```

---

## Example: Complete Workflow

```gdscript
extends Node

var _ariadne: AriadneInterface
var _wallet: WalletManager

func _ready() -> void:
    _ariadne = AriadneInterface.new()
    _wallet = WalletManager.new()

    # Load wallet
    if not _wallet.load_wallet("user://wallet.json"):
        push_error("Failed to load wallet")
        return

    _ariadne.set_default_wallet(_wallet.get_wallet_path())

    # Check if already initialized
    if _ariadne.is_initialized():
        print("Already tracking: ", _ariadne.get_repo_id())
        _show_status()
    else:
        _create_new_repo()

func _create_new_repo() -> void:
    var result = _ariadne.initialize(_wallet.get_wallet_path(), true)
    if result["exit_code"] == 0:
        print("Created: ", _ariadne.get_repo_id())
    else:
        push_error("Failed: " + result["output"])

func _show_status() -> void:
    var status = _ariadne.get_status()
    print("Branch: ", status["branch"])
    print("Clean: ", status["is_clean"])
    if not status["is_clean"]:
        print("Modified: ", status["modified"])

func _push_changes() -> void:
    var result = _ariadne.push()
    if result["exit_code"] == 0:
        print("Published: ", _ariadne.get_repo_id())
    else:
        push_error("Push failed: " + result["output"])
```

---

## Source Files

| Class | File |
|-------|------|
| `AriadneInterface` | `arweave/ariadne_interface.gd` |
| `WalletManager` | `arweave/wallet_manager.gd` |
