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

### ROS Coder Test

```bash
cd project
godot --headless scenes/ros_coder.tscn
```

Or open via main AI panel by clicking "ROS Coder" button.

**Expected output:**
```
ROS2 Python Coder window opens with:
- File browser (left panel, 180px)
- Code editor with Python syntax highlighting
- Prompt bar: [prompt input] [Generate] [Run] [Deploy]
- Console output panel (bottom)
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
| `scenes/test_ai.tscn` | AI/Minimax integration test |
| `scripts/test_ai.gd` | AI test script |
| `scenes/ros_coder.tscn` | ROS2 Python Coder IDE |
| `addons/ROSCoder/ros_coder.gd` | ROS Coder main controller |

## Known Issues

### Godot Headless Autoload Loading

When running `godot --headless` after clearing the `.godot/` cache, the `GodotROS2` autoload may fail to load due to Godot 4.4's `class_name` resolution ordering.

**Workaround:** Run `godot --editor` once to rebuild the class cache, then headless mode works.

```bash
rm -rf .godot
godot --editor --path . &
# Close immediately after it opens
godot --headless scenes/test_ai.tscn  # Now works
```

### ARIADNE "Not an ARIADNE repository"

This is **expected** before running `ariadne init`. Initialize with:

```bash
./node_modules/.bin/ariadne init --create --wallet wallet.json
```
