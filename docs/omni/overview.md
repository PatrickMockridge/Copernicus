# Omniverse Integration

NVIDIA Omniverse integration for USD pipeline, digital twin connectivity, and Isaac ecosystem interoperability.

---

## Overview

Omniverse integration enables Copernicus to:
- **Import USD files** - Load robot models and scenes from Omniverse
- **Export to USD** - Share scenes with Omniverse/Kit applications
- **Live sync** - Real-time digital twin with Omniverse Kit
- **Isaac compatibility** - Prepare scenes for Isaac Sim/Isaac Gym

---

## Available Connectors

| Connector | Description | Requirements |
|-----------|-------------|---------------|
| **USD Importer** | Load USD/USDZ files into Godot | None (uses pxr Python) |
| **USD Exporter** | Save Godot scenes to USD format | None (ASCII USDA fallback) |
| **OmniKit** | Live sync with Omniverse Kit | NVIDIA GPU + Omniverse |

---

## Architecture

```
addons/omni/
├── omni.gd                        # Plugin entry point
├── core/
│   ├── usd_types.gd              # USD type definitions
│   ├── usd_importer.gd           # USD file importer
│   └── usd_exporter.gd           # USD scene exporter
└── connectors/
    ├── omni_connector.gd         # Base connector interface
    └── omni_kit_connector.gd    # Omniverse Kit WebSocket bridge
```

---

## Quick Start

### 1. Enable the Plugin

In Project Settings → Plugins → Enable "Omniverse Integration"

### 2. Import a USD File

```gdscript
var importer = USDImporter.new()
var scene = importer.import_file("res://robots/franka.usd")

# Add to current scene
get_current_scene().add_child(scene)
```

### 3. Export to USD

```gdscript
var exporter = USDExporter.new()
exporter.configure({"scale": 1.0, "export_materials": true})

if exporter.export_scene(my_scene, "res://exports/robot.usda"):
    print("Exported successfully!")
```

---

## USD Importer

Load USD, USDA (ASCII), and USDC (binary) files into Godot scene tree.

### Basic Import

```gdscript
var importer = USDImporter.new()
var robot_scene = importer.import_file("res://models/panda.usd")
add_child(robot_scene)
```

### Validate USD File

```gdscript
var validation = importer.validate_file("res://robot.usd")
if validation["valid"]:
    print("Has robot: ", validation["has_robot"])
    print("Prim count: ", validation["prim_count"])
```

### Import Robot from USD

```gdscript
var importer = USDImporter.new()
var robot = importer.import_robot("res://robots/ur5.usd", "ur5_arm")

# Robot prims are extracted as separate scene graph
add_child(robot)
```

### How Import Works

```
1. Parse USD file via pxr.Usd Python bindings
2. Traverse stage hierarchy (prim tree)
3. Create Godot nodes matching prim types:
   - Xform → Node3D
   - Mesh → MeshInstance3D
   - Camera → Camera3D
   - Light → DirectionalLight3D/SpotLight3D/etc.
4. Apply transforms, materials, properties
```

---

## USD Exporter

Export Godot scenes to USD format for Omniverse interoperability.

### Basic Export

```gdscript
var exporter = USDExporter.new()
var scene = $RobotScene

if exporter.export_scene(scene, "res://exports/robot.usda"):
    print("USD exported!")
```

### Configuration

```gdscript
exporter.configure({
    "scale": 1.0,              # Export scale (1.0 = meters)
    "export_materials": true,   # Include material definitions
    "export_lights": true,      # Include light data
    "export_cameras": true      # Include camera data
})
```

### ASCII Export (No Dependencies)

```gdscript
# Generate ASCII USDA without Python/pxr
if exporter.export_as_ascii(scene, "res://robot.usda"):
    print("ASCII USD written!")
```

### How Export Works

```
1. Traverse Godot scene tree
2. Collect node data (transforms, meshes, materials)
3. Generate USD Python script using pxr.Usd
4. Execute script to write USD file
5. Fallback: Generate ASCII USDA directly (no pxr needed)
```

---

## Omniverse Kit Connector

Live bidirectional sync with Omniverse Kit applications.

### Connection

```gdscript
var connector = OmniKitConnector.new()
connector.configure({
    "uri": "ws://localhost:8210",
    "sync_interval": 0.1,
    "auto_sync": true
})

if connector.connect("ws://localhost:8210"):
    print("Connected to Omniverse Kit!")
```

### Scene Sync

```gdscript
# Sync entire scene
connector.sync_scene($RobotScene)

# Sync individual node
connector.sync_node($Robot/Arm/Joint)
```

### Transform Updates

```gdscript
# Send transform update
connector.send_transform("/World/Robot/Arm", some_transform)

# Track node for auto-sync
connector.track_node($Robot/Arm)
```

### Polling

```gdscript
# In _process():
func _process(delta):
    connector.poll()  # Handle WebSocket messages
```

---

## USD Types

Utilities for working with USD data.

### Path Utilities

```gdscript
var path = "/World/Robot/Arm/Joint"
var parent = USDTypes.parent_path(path)  # "/World/Robot/Arm"
var name = USDTypes.prim_name(path)      # "Joint"
```

### Transform Conversion

```gdscript
# Godot → USD matrix
var usd_matrix = USDTypes.godot_transform_to_usd_matrix(transform)

# USD matrix → Godot transform
var godot_transform = USDTypes.usd_matrix_to_godot_transform(matrix)
```

### Stage Info

```gdscript
var info = USDTypes.get_stage_info("res://robot.usd")
print("Prims: ", info["prim_count"])
print("Default prim: ", info["default_prim"])
```

---

## USD File Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| **USDA** | `.usda` | ASCII USD, human-readable |
| **USDC** | `.usdc` | Binary USD, compact |
| **USDZ** | `.usdz` | USD + assets bundled |

USDA is recommended for export (readable, version control friendly).
USDC is recommended for large scenes (smaller file size).

---

## Omniverse Kit WebSocket Protocol

OmniKit connector uses WebSocket to communicate with Omniverse Kit.

### Message Format

```json
{
  "type": "sync_scene",
  "payload": {
    "root": "Robot",
    "nodes": [...]
  }
}
```

### Supported Messages

| Type | Direction | Description |
|------|-----------|-------------|
| `sync_scene` | Godot → Kit | Full scene sync |
| `sync_node` | Godot → Kit | Single node sync |
| `transform_update` | Godot → Kit | Transform change |
| `material_update` | Godot → Kit | Material change |
| `scene_update` | Kit → Godot | Update from Kit |
| `sync_response` | Kit → Godot | Sync result |

---

## Use Cases

### 1. Import Omniverse Robot Models

```gdscript
# Load robot from Omniverse Ka-Robotics library
var robot = importer.import_file("~/Omniverse/Assets/Robots/Franka/panda.usd")
add_child(robot)
```

### 2. Export for Isaac Sim

```gdscript
# Export scene that can be opened in Isaac Sim
exporter.export_scene(scene, "~/IsaacSim/scene.usda")
```

### 3. Digital Twin with Omniverse Kit

```gdscript
# Connect to Omniverse Kit for live sync
var kit = OmniKitConnector.new()
kit.connect("ws://localhost:8210")

# Robot motions in Godot sync to Omniverse viewport
while kit.is_connected():
    kit.poll()
    # Update robot in Godot
    update_robot()
    kit.sync_node($Robot)
```

---

## Requirements

### USD Import/Export
- Python with `pxr` module: `pip install pxr`

### Omniverse Kit Connector
- NVIDIA GPU with RTX
- Omniverse Kit installed
- WS protocol enabled (port 8210)
- Omniverse Kit extension "WS Connector" enabled

---

## Troubleshooting

### USD Import Fails

```bash
# Install pxr
pip install pxr

# Verify
python3 -c "from pxr import Usd; print('pxr available')"
```

### Omniverse Kit Connection Refused

1. Verify Omniverse Kit is running
2. Check WS port 8210 is not blocked
3. Enable WS extension in Omniverse Kit
4. Verify no firewall blocking localhost

### Scene Looks Wrong in Omniverse

- Check export scale matches expected units
- Verify material textures are embedded or paths are correct
- Ensure transforms are in right coordinate system

---

## Architecture

```
Godot (Copernicus)          Omniverse Kit
     │                            │
     │  ──── Import USD ───────►  │
     │                            │
     │  ◄──── Export USD ──────  │
     │                            │
     │  ──── WebSocket sync ───► │
     │  (live transform updates) │
     │  ◄─── scene updates ──── │
     │                            │
     │         Isaac Sim          │
     │  ◄── High-fidelity sim ───┘
     │                            │
     │         Isaac Gym          │
     │  ◄─── GPU RL training ────┘
```

---

## See Also

- [URDF Import](../robots/urdf-import.md) — Robot model import
- [Industrial Plugin](../industrial/overview.md) — Industrial robot connectivity
- [ROS2 Bridge](../ros2/bridge.md) — ROS2 integration