# Getting Started

A Godot 4.x robotics simulator with ROS 2 integration and blockchain-backed design sharing.

## Requirements

- **Godot 4.4+** (recommended)
- **Node.js 22+** (for ARIADNE blockchain features)
- **Arweave wallet** (optional, for blockchain features)

## Quick Start

### 1. Clone and Open

```bash
git clone https://codeberg.org/PatrickM123/Godot_4__Robotic_Design_Interface.git
cd Godot_4__Robotic_Design_Interface
godot
```

### 2. Run Headless

```bash
godot --headless --quit
```

### 3. Install ARIADNE (Optional)

For blockchain design sharing:

```bash
npm install ariadne-cli
```

## Project Structure

```
.
├── addons/
│   ├── godot_ros2/          # ROS 2 simulator SDK
│   │   ├── core/           # Core classes (actuators, sensors, physics)
│   │   ├── sensors/        # Sensor implementations
│   │   ├── ros2/           # ROS 2 bridge client
│   │   └── arweave/        # Blockchain integration
│   └── GameAI/             # AI code agent (EXPERIMENTAL)
├── docs/                   # This documentation
├── scripts/                # Main scripts
└── scenes/                # Robot scene files
```

## What's Next?

### Learn ROS 2 Simulation
See [godot-ros2/README](godot-ros2/README.md) for creating robots with sensors and actuators.

### Share on Blockchain
See [arweave/README](../arweave/README.md) for publishing robot designs permanently.

### Code Patterns
See [development/code-patterns](development/code-patterns.md) for Godot 4.x compatibility patterns.

## Troubleshooting

### Parse Errors in Editor
If you see "Parse Error" in Godot editor:
```bash
rm -rf .godot
godot -e --headless --quit
```
This regenerates the Godot cache.

### Godot 4.3 vs 4.4
Godot 4.4 is recommended. Some type-checking features may differ in 4.3.

### ARIADNE Requires Node 22
If `ariadne` commands fail, ensure Node.js 22+ is installed:
```bash
node --version  # Should be v22+
```
