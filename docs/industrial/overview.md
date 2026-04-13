# Industrial Robot Plugin

ROS-Industrial plugin for Copernicus, providing connectivity to industrial robot controllers from MOTOMAN, ABB, FANUC, and Universal Robots.

---

## Overview

The industrial plugin bridges Copernicus with real industrial robot hardware, enabling:
- Joint trajectory preview and execution
- Real-time joint state monitoring
- Emergency stop and safety controls
- Digital I/O and register access

---

## Available Backends

| Backend | Protocol | Status |
|---------|----------|--------|
| **MockIndustrial** | None (testing) | Always available |
| **MOTOMAN** | INRC4 (TCP 50230) | Requires hardware |
| **OPC-UA** | OPC-UA | Coming soon |
| **ABB** | EtherNet/IP | Planned |
| **Universal Robots** | RTDB | Planned |
| **FANUC** | KAREL | Planned |

---

## Architecture

```
addons/industrial/
├── industrial.gd                    # Godot plugin entry point
├── plugin.cfg                      # Plugin configuration
├── industrial_selector.gd         # UI selector panel (self-contained)
├── core/
│   ├── industrial_backend.gd      # Abstract interface
│   ├── joint_trajectory_handler.gd # Trajectory execution
│   └── robot_status_monitor.gd    # State monitoring
└── backends/
    ├── mock_industrial.gd         # Testing mock
    ├── motoman_bridge.gd          # MOTOMAN INRC4 bridge
    └── opcua_bridge.gd            # OPC-UA bridge (stub)

scripts/industrial/
├── industrial_controller.gd        # High-level controller
└── industrial_controller.gd.uid   # UID file
```

---

## Quick Start

### 1. Load the Plugin

Enable the industrial plugin in Project Settings → Plugins:
```
Addons → Industrial Robot Interface → Enable
```

### 2. Run the Selector

```bash
godot scenes/industrial_selector.tscn
```

### 3. Connect to a Robot

```gdscript
var controller = IndustrialController.new()

# Connect to mock robot (for testing)
if controller.connect_robot("127.0.0.1", "MockIndustrial"):
    print("Connected!")

# Get joint positions
var joints = controller.get_joint_positions()
print("Joints: ", joints)
```

---

## IndustrialController

High-level controller combining backend, trajectory, and monitoring.

### Basic Usage

```gdscript
var controller = IndustrialController.new()

# Connect
controller.connect_robot("192.168.1.100", "MockIndustrial")

# Monitor status
var status = controller.get_robot_status()
print("Mode: ", controller.get_mode_string())
print("Joints: ", controller.get_joint_positions_formatted())

# Move joints
controller.move_joints([0.0, 0.5, -0.3, 0.0, 0.8, 0.0])

# Disconnect
controller.disconnect_robot()
```

### Trajectory Execution

```gdscript
# Load trajectory (from MoveIt! or similar)
var trajectory = [
    {"positions": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "time_from_start": 0.0},
    {"positions": [0.0, 0.5, -0.3, 0.0, 0.8, 0.0], "time_from_start": 2.0},
    {"positions": [0.5, 0.3, -0.5, 0.0, 0.6, 0.3], "time_from_start": 4.0}
]

controller.load_trajectory(trajectory)
controller.execute_trajectory()

# Monitor progress
while controller.get_trajectory_progress() < 1.0:
    print("Progress: ", controller.get_trajectory_progress() * 100, "%")
    await get_tree().create_timer(0.1).timeout
```

### Emergency Stop

```gdscript
# Trigger E-stop
controller.trigger_estop()

# Check if E-stop is active
if controller.is_estop_triggered():
    print("E-STOP ACTIVE!")

# Clear E-stop (requires hardware acknowledgment)
controller.clear_estop()
```

---

## IndustrialBackend Interface

Base interface for all industrial robot backends.

### Connection

```gdscript
func connect(address: String) -> bool
func disconnect()
func is_connected() -> bool
```

### Robot Status

```gdscript
func get_robot_status() -> Dictionary
func get_joint_positions() -> Array
func get_joint_velocities() -> Array
func get_joint_torques() -> Array
```

### Joint Trajectory

```gdscript
func send_joint_trajectory(trajectory: Array) -> bool
func execute_trajectory(points: Array) -> bool
func abort_trajectory()
func is_trajectory_running() -> bool
```

### Motion Control

```gdscript
func move_joints(positions: Array) -> bool
func move_cartesian(position: Vector3, orientation: Quaternion) -> bool
```

### Safety

```gdscript
func trigger_eston()
func clear_eston()
```

### Digital I/O

```gdscript
func read_digital_input(index: int) -> bool
func write_digital_output(index: int, value: bool) -> bool
```

### Registers

```gdscript
func read_register(address: int) -> float
func write_register(address: int, value: float) -> bool
```

---

## RobotStatusMonitor

Real-time robot state monitoring with history.

### Usage

```gdscript
var monitor = RobotStatusMonitor.new()
monitor.set_backend(backend)
monitor.start_monitoring(10.0)  # 10 Hz

# Connect to signals
monitor.status_changed.connect(_on_status_changed)
monitor.mode_changed.connect(_on_mode_changed)
monitor.e_stop_triggered.connect(_on_estop)

# Get current state
var status = monitor.get_current_status()
var positions = monitor.get_joint_positions()
var mode_str = RobotStatusMonitor.mode_to_string(monitor.get_mode())
```

### Status Dictionary

```gdscript
{
    "mode": 1,                    # 0=teach, 1=run, 2=stop, 3=error
    "e_stop_triggered": false,
    "error_code": 0,
    "joint_positions": [0.0, ...],
    "joint_velocities": [0.0, ...],
    "joint_torques": [0.0, ...],
    "controller_temperature": 35.0,
    "digital_inputs": [false, ...],
    "digital_outputs": [false, ...],
    "timestamp": {...}
}
```

---

## JointTrajectoryHandler

Time-parameterized trajectory execution.

### Usage

```gdscript
var handler = JointTrajectoryHandler.new()
handler.set_backend(backend)

# Set trajectory
handler.set_trajectory([
    {"positions": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "time_from_start": 0.0},
    {"positions": [0.5, 0.3, -0.5, 0.0, 0.6, 0.3], "time_from_start": 3.0}
])

# Set execution speed (0.0 to 1.0)
handler.set_speed(0.8)

# Execute
handler.execute()

# Process in physics loop
func _physics_process(delta):
    handler.process(delta)
```

### Signals

```gdscript
signal point_reached(point_index: int)
signal trajectory_started()
signal trajectory_completed()
signal trajectory_aborted()
signal error(message: String)
```

---

## MOTOMAN INRC4 Bridge

Connect to MOTOMAN robots via INRC4 protocol (port 50230).

### Connection

```gdscript
var bridge = MotomanBridge.new()
bridge.initialize({
    "robot_ip": "192.168.1.100",
    "port": 50230,
    "timeout": 5.0,
    "joint_count": 6
})

if bridge.connect("192.168.1.100"):
    print("MOTOMAN connected!")
```

### INRC4 Protocol

The INRC4 protocol uses TCP socket communication:

```
Header: "INRC" (4 bytes)
Length: 2 bytes (little-endian)
Type:   1 byte
Data:   variable
```

### Supported Commands

| Command | Description |
|---------|-------------|
| `0x01` | STATUS_READ - Read robot status |
| `0x02` | JOINT_WRITE - Write joint positions |
| `0x03` | JOINT_READ - Read joint positions |
| `0x10` | TRAJECTORY_START - Start trajectory |
| `0x11` | TRAJECTORY_POINT - Send trajectory point |
| `0x12` | TRAJECTORY_ABORT - Abort trajectory |
| `0x20` | ESTON_TRIGGER - Trigger E-stop |
| `0x21` | ESTON_CLEAR - Clear E-stop |
| `0x30` | IO_READ - Read digital I/O |
| `0x31` | IO_WRITE - Write digital I/O |
| `0x40` | REGISTER_READ - Read register |
| `0x41` | REGISTER_WRITE - Write register |

---

## MockIndustrial Backend

Testing backend that simulates robot behavior without hardware.

### Features

- Simulated joint positions, velocities, torques
- Trajectory execution simulation
- E-stop and error simulation
- Digital I/O and register read/write
- Configurable joint count

### Usage

```gdscript
var mock = MockIndustrial.new()
mock.initialize({
    "robot_ip": "127.0.0.1",
    "joint_count": 6
})

mock.connect("127.0.0.1")

# Set simulated joint positions
mock.set_joint_positions([0.1, 0.2, 0.3, 0.4, 0.5, 0.6])

# Simulate error
mock.trigger_simulated_error()

# Read status
var status = mock.get_robot_status()
```

---

## Common Issues

### Connection Failed

- Verify robot IP address and port
- Check network connectivity
- Ensure robot controller is configured for external communication
- Verify no firewall blocking the connection

### Trajectory Not Executing

- Check robot mode (must be in RUN mode)
- Verify E-stop is not triggered
- Check trajectory point format
- Verify trajectory points are within joint limits

### Joint Positions Mismatch

- Verify joint count matches robot
- Check URDF or robot description matches actual robot
- Verify joint order matches robot convention

---

## Example: Full Robot Control Session

```gdscript
extends Node3D

var _controller: IndustrialController

func _ready():
    _controller = IndustrialController.new()
    _controller.status_changed.connect(_on_status_changed)
    _controller.trajectory_completed.connect(_on_trajectory_done)
    _controller.error_occurred.connect(_on_error)

    # Connect to robot
    if _controller.connect_robot("192.168.1.100", "MockIndustrial"):
        print("Robot connected: ", _controller.get_robot_name())
        print("Status: ", _controller.get_status_summary())

func execute_pick_place():
    # Move to home
    _controller.move_joints([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    await _wait_for_done()

    # Move to pick
    _controller.move_joints([0.5, -0.3, 0.8, 0.0, 0.5, 0.0])
    await _wait_for_done()

    # Execute pick trajectory
    var pick_trajectory = [
        {"positions": [0.5, -0.3, 0.8, 0.0, 0.5, 0.0], "time_from_start": 0.0},
        {"positions": [0.5, -0.2, 0.6, 0.0, 0.6, 0.0], "time_from_start": 2.0},
        {"positions": [0.5, -0.1, 0.4, 0.0, 0.7, 0.0], "time_from_start": 4.0}
    ]

    _controller.load_trajectory(pick_trajectory)
    _controller.execute_trajectory()

func _wait_for_done():
    while _controller.get_trajectory_progress() < 1.0:
        await get_tree().create_timer(0.1).timeout

func _on_status_changed(status: Dictionary):
    print("Status: ", _controller.get_status_summary())

func _on_trajectory_done(success: bool):
    print("Trajectory ", "completed" if success else "aborted")

func _on_error(message: String):
    print("Error: ", message)

func _exit_tree():
    if _controller:
        _controller.shutdown()
```

---

## See Also

- [URDF Import](../robots/urdf-import.md) — Robot model structure
- [Control](../robots/control.md) — Joint control fundamentals
- [IK Solvers](../navigation/ik-solvers.md) — Robot arm planning
- [Navigation](../navigation/planners.md) — Mobile robot navigation