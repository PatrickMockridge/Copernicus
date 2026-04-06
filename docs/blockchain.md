# Blockchain Integration

Publish robot designs to Arweave and trade them as AO Hyperobjects.

## Architecture

```
Robot Design (RobotModel)
    │
    ├─► ARIADNE.push() ─► Arweave TX ID (permanent storage)
    │
    └─► AO Hyperobject ─► AO Process (ownership, transfer)
```

- **ARIADNE** — Decentralized git hosting on Arweave
- **AO Hyperobjects** — Actor-Oriented compute for ownership and trading

## Requirements

| Component | Notes |
|-----------|-------|
| Node.js | 22+ |
| Arweave Wallet | JWK format |

## Installation

### Install ARIADNE CLI

```bash
npm install -g ariadne-cli
```

### Create Wallet

Use an existing Arweave wallet in JWK format:

```json
{
  "kty": "RSA",
  "n": "...",
  "e": "AQAB",
  "kid": "your_address_here"
}
```

## Wallet Setup

Load wallet once at startup:

```gdscript
var result = WalletService.get_instance().load_wallet("res://wallet.json")
if result.is_err():
    print("Wallet load failed: ", result.get_error())
```

## Publishing a Robot Design

```gdscript
# Initialize ARIADNE
var ariadne = AriadneInterface.new()
ariadne.initialize("", true)  # --create flag

# Create robot hyperobject
var robot = RobotHyperobject.from_robot_model(robot_model, ariadne, ao)
var result = robot.publish()

if result.exit_code == 0:
    print("Published! repo_id: ", result.repo_id)
    print("AO process_id: ", result.process_id)
```

## Trading Robots

```gdscript
var trade_manager = TradeManager.new(ao, ariadne)

# List for sale
trade_manager.list_for_sale(repo_id, 10.0)  # 10 AR

# Remove from sale
trade_manager.unlist(repo_id)

# Transfer ownership
trade_manager.transfer(repo_id, new_owner_address)

# Purchase
trade_manager.purchase(repo_id)
```

## Querying Robots

```gdscript
# Get robots owned by address
var owned = trade_manager.get_robots_by_owner(wallet_address)

# Get all robots for sale
var for_sale = trade_manager.get_robots_for_sale()

# Search by name
var results = trade_manager.search_by_name("turtlebot")
```

## Key Classes

| Class | Purpose |
|-------|---------|
| `WalletService` | Singleton — single source of truth for wallet |
| `ArweaveWallet` | JWK wallet wrapper |
| `AriadneInterface` | Wrapper for ariadne-cli |
| `RobotHyperobject` | Bridge — ARIADNE repos + AO processes |
| `TradeManager` | Registry and trading operations |
| `AOSDK` | AO Hyperobject SDK |

## ARIADNE CLI Commands

```bash
# Initialize new repo
ariadne init --create --wallet wallet.json

# Push to Arweave
ariadne push --wallet wallet.json

# Clone a repo
ariadne clone <repo_id> --wallet wallet.json

# Check status
ariadne status
```

For more on ARIADNE CLI, see [ariadne-cli repository](https://codeberg.org/PatrickM123/ARIADNE).
