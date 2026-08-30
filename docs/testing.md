# Testing

Test procedures for verifying the robot design interface.

## Running Tests

### Prerequisites

```bash
export ROS_DOMAIN_ID=0
```

### Blockchain Test

```bash
cd project
godot --headless scenes/test_blockchain.tscn
```

**Expected output:**
```
=== Blockchain Test Starting ===
Services initialized
--- Testing Wallet ---
Wallet loaded! Address: test_wallet_001
--- Testing AO SDK ---
AO SDK initialized: true
--- Testing Publish Flow ---
Push result: { "exit_code": 1, "output": "...Not an ARIADNE repository..." }
=== Blockchain Test Complete ===
Summary:
- Wallet loaded: true
- ARIADNE initialized: false
```

The "not initialized" error is **expected** before running `ariadne init`.

### AI Test

```bash
godot --headless scenes/test_ai.tscn
```

**Expected output:**
```
=== AI Test Starting ===
--- Test 1: EnvService API Key ---
PASS: Anthropic API key found (length=125)
--- Test 2: AI Configuration ---
Default provider: anthropic
--- Test 3: Anthropic Chat ---
PASS: Chat response received
--- Test 4: Generate Behavior ---
```

### ROS 2 Bridge

```bash
# Terminal 1: Build and run bridge
cd ~/ros2_ws && source /opt/ros/jazzy/setup.bash
colcon build --packages-select godot_ros2_bridge
source install/setup.sh
ros2 run godot_ros2_bridge godot_bridge_node
```

```bash
# Terminal 2: Verify topics
export ROS_DOMAIN_ID=0
ros2 topic list
# Should show /parameter_events and /rosout
```

## Test Files

| File | Purpose |
|------|---------|
| `scenes/test_blockchain.tscn` | Blockchain integration test |
| `scripts/test_blockchain.gd` | Blockchain test script |
| `scenes/test_ai.tscn` | AI test (legacy) |
| `scripts/test_ai.gd` | AI test script (legacy) |
| `scripts/test_ai_client.gd` | AI client test |
| `scripts/test_ai_tools.gd` | AI tools test |

## Known Issues

### GodotROS2 Autoload (Refactored for Godot 4.4)

The `godot_ros2` addon was previously disabled due to systemic circular type dependency issues in Godot 4.4. It has been **refactored** and is now **enabled**.

**What was fixed:**
- Removed all cross-file type annotations from the 14 essential files
- Deleted non-essential stub files (sensors, robots, actuators, arweave, simulators)
- Converted typed class variables to untyped (`var _x` instead of `var _x: TypeName`)
- Converted typed method parameters to untyped
- Converted typed method returns to untyped
- Used `load("path")` for dynamic instantiation

**Files fixed:**
- `godot_ros2.gd` — autoload entry point
- `core/ros2_executor.gd` — spin executor
- `core/ros2_node.gd` — node wrapper
- `ros2/publisher.gd`, `ros2/subscription.gd`, `ros2/service_client.gd`, `ros2/action_client.gd`

**Files removed (stubs/unused):**
- All sensor files (stub implementations)
- All robot/simulation files (unused)
- All arweave files (separate blockchain system, not ROS2)
- `ros2/file_manager.gd` (removed — ROS Coder is dormant)
- Various stub actuator, controller, and plugin files

**Limitation:** The addon now uses untyped variables internally, losing compile-time type safety. Runtime behavior is unchanged.

**Proper fix would require:** A complete architecture redesign that eliminates circular dependencies, or moving the ROS2 bridge to a GDExtension/C++ module.

### ARIADNE "Not an ARIADNE repository"

### ARIADNE "Not an ARIADNE repository"

This is **expected** before running `ariadne init`. Initialize with:

```bash
./node_modules/.bin/ariadne init --create --wallet wallet.json
```
