# ARIADNE Blockchain Interface

Permanently share robot designs on the Arweave/AO blockchain.

## Overview

ARIADNE provides decentralized git repository hosting on Arweave — your robot designs persist forever without a central server.

## Requirements

- **Node.js 22+**
- **Arweave wallet** (JWK format)

## Installation

```bash
npm install ariadne-cli
```

## Quick Start

```gdscript
var ariadne = AriadneInterface.new()
var wallet = WalletManager.new()

wallet.load_wallet("user://wallet.json")
ariadne.set_default_wallet(wallet.get_wallet_path())

# Initialize new repository
ariadne.initialize(wallet.get_wallet_path(), true)

# Push to blockchain
ariadne.push()
```

## Documentation

- [Getting Started](getting-started.md) — Setup and first publish
- [API Reference](api-reference.md) — Full API documentation

## What ARIADNE Provides

- **Permanent Storage** — Designs persist forever on Arweave
- **Decentralized** — No central server, anyone can run their own instance
- **Private Repos** — AES-256-GCM encryption with RSA key exchange
- **Git Integration** — Works with standard git workflows

## Source Files

```
addons/godot_ros2/arweave/
├── ariadne_interface.gd  # Main wrapper
├── wallet_manager.gd      # Wallet handling
├── plugin.cfg            # Plugin config
└── README.md            # Module README
```

For more details on the CLI, see the [ariadne-cli repository](https://codeberg.org/PatrickM123/ARIADNE).
