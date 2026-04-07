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
| Godot | 4.4+ |
| Node.js | 18+ (ariadne-cli) |
| Arweave Wallet | JWK format |

## Testing

### Run Blockchain Test

```bash
cd project
godot --headless scenes/test_blockchain.tscn
```

### Test Script Location
- Scene: `scenes/test_blockchain.tscn`
- Script: `scripts/test_blockchain.gd`

### Expected Output

```
=== Blockchain Test Starting ===
Services initialized

--- Testing Wallet ---
Found wallet at: res://wallet.json
Wallet loaded! Address: test_wallet_001

--- Testing ARIADNE ---
Using node: /usr/bin/node
ARIADNE initialized in project: false
ARIADNE not initialized - will need to init before publish

--- Testing AO SDK ---
AO SDK initialized: true

--- Testing Publish Flow ---
RobotHyperobject created
- Repo ID:
- Owner:

Attempting ARIADNE push...
Push result: { "exit_code": 1, "output": "...Not an ARIADNE repository..." }

=== Blockchain Test Complete ===
Summary:
- Wallet loaded: true
- Wallet address: test_wallet_001
- ARIADNE initialized: false
- Robots registered: 0
```

The "not initialized" error is **expected** before running `ariadne init`.

## Initializing ARIADNE

```bash
# Initialize with wallet
./node_modules/.bin/ariadne init --create --wallet wallet.json

# Or use the CLI directly
ariadne init --create --wallet wallet.json
```

## Wallet Setup

Place wallet in project root as `wallet.json`:

```json
{
  "kty": "RSA",
  "n": "...",
  "e": "AQAB",
  "kid": "your_address_here"
}
```

Load wallet in code:

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

| Class | File | Purpose |
|-------|------|---------|
| `WalletService` | `wallet_service.gd` | Singleton — single source of truth for wallet |
| `ArweaveWallet` | `arweave_wallet.gd` | JWK wallet wrapper |
| `AriadneInterface` | `ariadne_interface.gd` | Wrapper for ariadne-cli |
| `RobotHyperobject` | `robot_hyperobject.gd` | Bridge — ARIADNE repos + AO processes |
| `TradeManager` | `trade_manager.gd` | Registry and trading operations |
| `AOSDK` | `ao.gd` | AO Hyperobject SDK |
| `HyperHttpClient` | `http_client.gd` | HTTP client (stubbed) |

## Godot 4.4 Migration Notes

The blockchain code has been migrated to Godot 4.4:

- `JSON.parse()` → `JSON.parse_string()`
- `class_name HttpClient` → `class_name HyperHttpClient` (avoids native class conflict)
- `OS.expand_environment()` → `OS.get_environment()`
- Nested classes restructured
- `WalletService` added `class_name` declaration

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

## Cost Notes

- **ArDrive uploads under 100kB are free**
- **AO is gasless right now** (no AO token gas fees)
