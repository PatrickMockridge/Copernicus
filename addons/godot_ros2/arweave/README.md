# ARIADNE Blockchain Interface

GDScript wrapper for [ariadne-cli](https://codeberg.org/PatrickM123/ARIADNE) - decentralized git repository hosting on Arweave/AO blockchain.

## Features

- **Permanent Storage**: Robot designs stored forever on Arweave blockchain
- **Decentralized**: No central server required
- **Private Repos**: Optional AES-256-GCM encryption
- **Git Integration**: Works with standard git workflows

## Requirements

- Node.js 22+ (for ariadne-cli)
- Arweave wallet (JWK format)
- `node_modules/ariadne-cli` in project root

## Installation

1. Install Node.js 22 via nvm:
   ```bash
   nvm install 22
   nvm use 22
   ```

2. Install ariadne-cli:
   ```bash
   npm install ariadne-cli
   ```

3. Enable the plugin in Godot via `Project > Project Settings > Plugins`

## Quick Start

```gdscript
extends Node

var _ariadne: AriadneInterface
var _wallet: WalletManager

func _ready() -> void:
    _ariadne = AriadneInterface.new()
    _wallet = WalletManager.new()

    # Load your Arweave wallet
    if _wallet.load_wallet("user://wallet.json"):
        _ariadne.set_default_wallet(_wallet.get_wallet_path())
        print("Wallet loaded: ", _wallet.get_address())

    # Check if already initialized
    if _ariadne.is_initialized():
        print("Repo ID: ", _ariadne.get_repo_id())
    else:
        # Create new repository on Arweave
        var result = _ariadne.initialize(_wallet.get_wallet_path(), true)
        print("Init result: ", result["output"])

    # Push to blockchain
    var push_result = _ariadne.push()
    print("Push output: ", push_result["output"])
```

## Wallet Setup

Create an Arweave wallet:
1. Get an Arweave wallet at https://arconnect.io or https://ardrive.io
2. Export as JWK JSON file
3. Place in `user://wallet.json` or another location

```gdscript
# Load wallet from custom path
_wallet.load_wallet("res://arweave-wallet.json")
```

## API Reference

### AriadneInterface

| Method | Returns | Description |
|--------|---------|-------------|
| `is_initialized()` | bool | Check if `.gitariadne` exists |
| `get_repo_id()` | String | Get current repository ID |
| `initialize(wallet, create, private)` | Dictionary | Initialize tracking |
| `push(wallet, private)` | Dictionary | Push to Arweave |
| `pull()` | Dictionary | Pull from Arweave |
| `clone(repo_id, wallet)` | Dictionary | Clone a repo |
| `get_status()` | Dictionary | Get working tree status |
| `get_log(limit)` | Array | Get commit history |

### WalletManager

| Method | Returns | Description |
|--------|---------|-------------|
| `load_wallet(path)` | bool | Load JWK wallet file |
| `get_address()` | String | Get wallet address |
| `has_wallet()` | bool | Check if wallet loaded |
| `set_wallet_path(path)` | void | Set wallet path |

## Example: Publishing a Robot Design

```gdscript
func publish_robot_design() -> void:
    var ariadne = AriadneInterface.new()
    var wallet = WalletManager.new()

    # Load wallet
    if not wallet.load_wallet("user://wallet.json"):
        push_error("Failed to load wallet")
        return

    ariadne.set_default_wallet(wallet.get_wallet_path())

    # Initialize if new project
    if not ariadne.is_initialized():
        var init_result = ariadne.initialize(wallet.get_wallet_path(), true)
        if init_result["exit_code"] != 0:
            push_error("Init failed: " + init_result["output"])
            return

    # Push to blockchain
    var push_result = ariadne.push()
    if push_result["exit_code"] == 0:
        print("Published! Repo ID: ", ariadne.get_repo_id())
    else:
        push_error("Push failed: " + push_result["output"])
```

## Example: Cloning a Robot Design

```gdscript
func clone_design(repo_id: String) -> void:
    var ariadne = AriadneInterface.new()
    var wallet = WalletManager.new()

    wallet.load_wallet("user://wallet.json")
    ariadne.set_default_wallet(wallet.get_wallet_path())

    var result = ariadne.clone(repo_id, wallet.get_wallet_path())
    if result["exit_code"] == 0:
        print("Cloned successfully!")
    else:
        push_error("Clone failed: " + result["output"])
```

## Status Output Format

`get_status()` returns:
```gdscript
{
    "branch": "main",
    "staged": ["file1.gd", "file2.gd"],
    "modified": ["file3.gd"],
    "untracked": ["new_file.gd"],
    "is_clean": false
}
```

## Notes

- The wrapper uses `OS.execute()` to call ariadne-cli
- Requires Node.js 22+ at `~/.nvm/versions/node/v22.22.2/bin/node`
- Wallet must be JWK format (ArConnect/ArDrive export)
- Private repositories use AES-256-GCM encryption
