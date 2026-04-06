# ARIADNE Getting Started

Publish robot designs permanently to the Arweave blockchain.

## Prerequisites

- Node.js 22+
- Git repository with your robot design
- Arweave wallet (JWK format)

## Step 1: Install ariadne-cli

```bash
npm install ariadne-cli
```

Or use directly:
```bash
npx ariadne-cli <command>
```

## Step 2: Create an Arweave Wallet

1. Get a wallet from [ArConnect](https://arconnect.io) or [ArDrive](https://ardrive.io)
2. Export as JWK JSON file
3. Note the file path

## Step 3: Initialize Git Repository

```bash
cd your-robot-project
git init
git add .
git commit -m "Initial robot design"
```

## Step 4: Initialize ARIADNE

```bash
# Using npx
npx ariadne-cli init --create --wallet ./wallet.json

# Or set wallet path and run
export ARWEAVE_WALLET=./wallet.json
npx ariadne-cli init --create
```

This creates your repository on Arweave and saves the `.gitariadne` config.

## Step 5: Push Updates

After making changes:

```bash
git add .
git commit -m "Updated robot parameters"
npx ariadne-cli push --wallet ./wallet.json
```

## Using from Godot

```gdscript
extends Node

var _ariadne: AriadneInterface
var _wallet: WalletManager

func _ready() -> void:
    _ariadne = AriadneInterface.new()
    _wallet = WalletManager.new()

    # Load wallet
    _wallet.load_wallet("user://wallet.json")
    _ariadne.set_default_wallet(_wallet.get_wallet_path())

    # Check if initialized
    if _ariadne.is_initialized():
        print("Repo ID: ", _ariadne.get_repo_id())

        # Check status
        var status = _ariadne.get_status()
        print("Clean: ", status["is_clean"])
    else:
        # Create new repository
        var result = _ariadne.initialize(_wallet.get_wallet_path(), true)
        print(result["output"])

func _on_push_pressed() -> void:
    var result = _ariadne.push()
    if result["exit_code"] == 0:
        print("Published! Repo ID: ", _ariadne.get_repo_id())
    else:
        print("Error: ", result["output"])
```

## Private Repositories

Encrypt your robot designs so only authorized users can access:

```bash
npx ariadne-cli init --create --private --wallet ./wallet.json
npx ariadne-cli push --private --wallet ./wallet.json
```

To clone a private repo:
```bash
npx ariadne-cli clone <repo-id> --wallet ./wallet.json
```

## Viewing Your Repository

After pushing, your repo is permanently stored on Arweave. Access via:
- `https://ariadne.gateway.com/<repo-id>`
- `https://arweave.net/<repo-id>`

## Troubleshooting

### "Node 22+ required"
```bash
node --version  # Must be v22+
nvm install 22
nvm use 22
```

### "Wallet required"
Ensure your wallet file exists and is valid JWK format:
```json
{"kty":"RSA","n":"...","e":"AQAB",...}
```

### "Not a git repository"
Run `git init` first before `ariadne init`.

## Next Steps

See [API Reference](api-reference.md) for all available methods.
