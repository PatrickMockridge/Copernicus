# Marketplace Module

Copernicus includes a decentralized marketplace for trading robot designs, components, and environments using AO Hyperobjects and Arweave storage.

## Overview

```
┌────────────────────────────────────────────────────────────┐
│                    COPERNICUS MARKETPLACE                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────────┐ │
│  │ Browse/  │  │ Create   │  │ My Listings /             │ │
│  │ Search   │  │ Listing  │  │ Purchases                 │ │
│  └──────────┘  └──────────┘  └──────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Asset Detail Panel                                    │  │
│  │ Preview | Description | Price | Buy                  │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ AO Hyperobject Layer (AO Process per asset)          │  │
│  │ State: owner, price, type, metadata, file_refs      │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

## Architecture

```
scripts/marketplace/
├── marketplace_core.gd           # Abstract marketplace interface
├── marketplace_selector.gd       # Backend selection UI
├── listing.gd                    # Listing data structure
├── backends/
│   ├── ao_marketplace.gd          # Real AO Hyperobject marketplace
│   ├── rchain_marketplace.gd      # RChain coordination backend
│   └── mock_marketplace.gd        # Testing marketplace
└── ui/
    └── marketplace_panel.gd       # Main marketplace panel UI
```

---

## Asset Types

| Type | Description | Examples |
|------|-------------|----------|
| **Robot** | Complete robot designs | TurtleBot, robotic arm, quadruped |
| **Part** | Components | Grippers, sensors, wheels, cameras |
| **World** | Environments | Warehouse, lab, outdoor terrain |

---

## Marketplace Backends

### Mock Marketplace (Default for Testing)

```gdscript
var marketplace = MockMarketplace.new()
var listings = marketplace.load_listings()
```

Features sample data for testing without real blockchain.

### AO Marketplace (Production)

```gdscript
var marketplace = AOMarketplace.new()
marketplace.initialize({"ao": ao_sdk, "wallet": wallet})
var listings = marketplace.load_listings()
```

Real decentralized marketplace using AO Hyperobjects.

### RChain Marketplace (Coordination)

```gdscript
var marketplace = RChainMarketplace.new()
marketplace.initialize({"coordination": coordination})
var listings = marketplace.load_listings()
```

On-chain marketplace backed by RChain/RNode. A listing is a **capability transfer**:
`create_listing` mints a robot capability and registers it in the rholang registry;
`purchase_listing` transfers that capability to the buyer. Asset blobs still upload
to Arweave (via `Storage`); only the TX id, metadata, and authority live on RChain.
See [RChain Coordination](../../rchain/design.md) for the full model.

```

---

## Basic Usage

### Opening the Marketplace

```gdscript
# Via selector (recommended)
var selector = preload("res://scenes/marketplace/marketplace_selector.tscn").instantiate()
add_child(selector)
selector.backend_selected.connect(_on_backend_selected)

func _on_backend_selected(backend_id: String):
    var backend = MarketplaceSelector.create_backend(backend_id)
    var panel = preload("res://scenes/marketplace/marketplace_panel.tscn").instantiate()
    add_child(panel)
```

### Direct Marketplace Panel

```gdscript
var panel = preload("res://scenes/marketplace/marketplace_panel.tscn").instantiate()
add_child(panel)
```

---

## Listing Data Structure

```gdscript
var listing = Listing.new()
listing._name = "My Robot"
listing._asset_type = Listing.AssetType.ROBOT
listing._price = 1000000000000  # 1 AR in winston
listing._description = "A differential drive robot"
listing._files = [{"name": "robot.tscn", "path": "res://robot.tscn"}]
```

### Serialization

```gdscript
# To dictionary
var dict = listing.to_dictionary()

# From dictionary
var restored = Listing.from_dictionary(dict)
```

---

## Core Methods

### Load Listings

```gdscript
var listings = marketplace.load_listings({
    "asset_type": "ROBOT",
    "min_price": 100000000000,  # 0.1 AR
    "max_price": 10000000000000  # 10 AR
})
```

### Search

```gdscript
var results = marketplace.search_listings("turtle", {
    "asset_type": "ROBOT"
})
```

### Create Listing

```gdscript
var listing = marketplace.create_listing({
    "name": "My Awesome Robot",
    "asset_type": "ROBOT",
    "description": "A robot I designed",
    "price": 500000000000,  # 0.5 AR
    "files": ["res://my_robot.tscn", "res://my_robot.gd"]
})
```

### Purchase

```gdscript
if marketplace.purchase_listing(listing_id):
    print("Purchased successfully!")
```

---

## AO Hyperobject Integration

Each listing is an AO Hyperobject process with state:

```json
{
    "type": "LISTING",
    "asset_type": "ROBOT",
    "name": "My Robot",
    "description": "...",
    "price": 1000000000000,
    "owner": "wallet_address",
    "creator": "creator_address",
    "files": [{"name": "robot.tscn", "tx_id": "..."}],
    "preview_tx_id": "...",
    "manifest_tx_id": "...",
    "created": 1712000000,
    "state": "ACTIVE"
}
```

### Purchase Flow

```
1. Buyer clicks "Purchase"
2. Verify AR balance sufficient
3. Send AO message: {action: "purchase", buyer, price}
4. Listing process updates owner
5. Buyer receives file access
```

---

## File Storage

Files are uploaded to Arweave via the Storage module:

- Each file gets a unique TX ID
- Manifest TX ID links all files
- Preview image stored separately
- Content-Type tags for proper rendering

### Supported File Types

| Extension | Content-Type |
|-----------|--------------|
| `.gd`, `.gdscript` | text/plain |
| `.tscn`, `.escn` | text/plain |
| `.png` | image/png |
| `.jpg` | image/jpeg |
| `.obj`, `.glb` | model/gltf-binary |
| `.urdf` | application/xml |

---

## Price Formatting

```gdscript
# Winston to AR string
var price_str = MarketplaceCore.format_price(1000000000000)
# Returns "1.00 AR"

# AR string to winston
var winston = MarketplaceCore.parse_price("0.5")
# Returns 500000000000
```

---

## UI Components

### MarketplacePanel

Main marketplace interface with tabs:
- **Browse**: All active listings
- **My Listings**: Your listings for sale
- **Create**: Create new listing
- **Purchases**: Listings you've bought

### Asset Card

Single listing preview widget:
- Preview image
- Name and creator
- Price
- View/Buy buttons

### Asset Detail Panel

Full listing view:
- Large preview
- Description
- File list
- Price and Buy button

---

## Integration with Publish Flow

The marketplace integrates with the existing robot publishing:

1. Publish a robot via File > Publish
2. Choose "List on Marketplace" option
3. Set price and description
4. Robot becomes a marketplace listing

---

## When to Use Which Backend

| Scenario | Backend |
|---------|---------|
| Testing without wallet | MockMarketplace |
| No AR tokens | MockMarketplace |
| Production use | AOMarketplace |
| Small transactions | AOMarketplace |
| On-chain capability coordination | RChainMarketplace |

---

## Adding New Marketplace Backends

Implement the `MarketplaceCore` interface:

```gdscript
class_name MyMarketplace
extends MarketplaceCore

func create_listing(config: Dictionary) -> Listing:
    # Your implementation
    pass

func purchase_listing(listing_id: String) -> bool:
    # Your implementation
    pass

func load_listings(filter: Dictionary = {}) -> Array:
    # Your implementation
    pass

# ... implement all required methods
```

Register in `MarketplaceSelector`:
```gdscript
_add_marketplace_option("MyMarketplace", "My Marketplace",
    "Description", MyMarketplace.is_available())
```

---

## Architecture

```
scripts/marketplace/
├── marketplace_core.gd           # Abstract interface
├── marketplace_selector.gd        # Backend selection UI
├── listing.gd                    # Listing data class
├── backends/
│   ├── ao_marketplace.gd          # AO Hyperobject backend
│   ├── rchain_marketplace.gd      # RChain coordination backend
│   └── mock_marketplace.gd        # Mock backend for testing
└── ui/
    └── marketplace_panel.gd       # Main UI panel

scenes/
└── marketplace/
    ├── marketplace_selector.tscn  # Selector scene
    └── marketplace_panel.tscn      # Main panel scene

addons/
├── hyperobject/sdk/              # AO SDK
│   ├── ao.gd                    # Compute Unit
│   └── storage.gd               # Arweave storage
└── primitives/
    └── wallet/                   # Wallet integration
```

---

**Note:** The AO marketplace requires a wallet with AR tokens for real transactions. Use the mock marketplace for testing and development.
