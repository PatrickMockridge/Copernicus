# IK Solver Module

Copernicus supports swappable IK (Inverse Kinematics) solvers for robot arm and chain manipulation.

## Overview

```
Copernicus (Visualizer + Controller)
    │
    ├── IK Solver Interface (abstract)
    │       │
    │       ├── Analytical IK (CCD, FABRIK) ← No external deps
    │       │       OR
    │       └── MoveIt IK ← Via ROS2, industry standard
```

## Solver Comparison

| Solver | Accuracy | Speed | Dependencies | Use Case |
|--------|----------|-------|--------------|----------|
| **Analytical (CCD)** | Moderate | Fast | None | Simple chains, robot arms |
| **Analytical (FABRIK)** | Moderate | Fast | None | Natural motion, tentacles |
| **MoveIt** | High | Slower | ROS2 | Industry, complex robots |

## Why Multiple Solvers?

Different robots and tasks need different approaches:

- **Analytical solvers** work well for simple serial chains (robot arms)
- **MoveIt** handles complex robots with collision avoidance, constraints, and multiple chains

## Analytical IK (Default)

Pure GDScript implementations - no external dependencies.

### CCD (Cyclic Coordinate Descent)

Iterative solver that works from the end effector backward:

```
Target → Joint N → Joint N-1 → ... → Joint 1
```

**Best for:**
- Serial chains (robot arms)
- Simple 2-6 joint chains
- When you need speed over accuracy

```gdscript
var solver = AnalyticalIKSolver.new()
solver.initialize({"algorithm": AnalyticalIKSolver.Algorithm.CCD})
solver.set_max_iterations(10)
solver.set_tolerance(0.001)

if solver.solve(joint_chain, target_position):
    var rotations = solver.get_joint_rotations()
```

### FABRIK (Forward And Backward Reaching IK)

Natural, chain-wide solver:

```
Forward: Pull end toward target
Backward: Constrain base to origin
Repeat until converged
```

**Best for:**
- Tentacle-style chains
- Natural-looking motion
- When joint limits matter

```gdscript
var solver = AnalyticalIKSolver.new()
solver.initialize({"algorithm": AnalyticalIKSolver.Algorithm.FABRIK})
solver.set_max_iterations(20)
```

## MoveIt IK (Industry Grade)

Connects to ROS2 MoveIt for industry-standard IK.

**Requirements:**
- ROS2 installed
- MoveIt configured with robot description
- `moveit_ros` packages

```bash
# Check if ROS2/MoveIt is available
ros2 pkg list | grep moveit
```

```gdscript
var solver = MoveItIKBridge.new()
solver.initialize({
    "robot_description": "robot_description",
    "group_name": "manipulator",
    "timeout": 0.5
})

if solver.solve(joint_chain, target_position):
    var rotations = solver.get_joint_rotations()
```

## IK Solver Interface

All solvers implement `IKSolver`:

```gdscript
class_name IKSolver

func initialize(config: Dictionary) -> bool
func solve(chain: Array, target: Vector3) -> bool
func get_joint_rotations() -> Array
func get_end_effector_position() -> Vector3
func get_final_distance() -> float
func set_max_iterations(iterations: int)
func set_tolerance(tolerance: float)
```

### Joint Chain Format

```gdscript
var chain = [
    {
        "node": joint1_node,
        "position": Vector3(0, 0, 0),
        "rotation": Quaternion.IDENTITY,
        "axis": Vector3(0, 1, 0),  # Y-axis rotation
        "min_angle": -PI,
        "max_angle": PI
    },
    {
        "node": joint2_node,
        "position": Vector3(0, 0.5, 0),
        "rotation": Quaternion.IDENTITY,
        "axis": Vector3(0, 1, 0),
        "min_angle": -PI/2,
        "max_angle": PI/2
    },
    # ... more joints
]
```

## Using the IK Selector

Open the IK selector panel:

```bash
godot scenes/ik_selector.tscn
```

Select your desired solver and click **Apply**.

## Programmatic Solver Selection

```gdscript
# Get available solvers
var available = IKSelector.get_available_solvers()

# Create a specific solver
var solver = IKSelector.create_solver("AnalyticalIKSolver", {
    "algorithm": AnalyticalIKSolver.Algorithm.CCD,
    "max_iterations": 15
})
```

## Basic Usage Example

```gdscript
# Create a simple 3-joint arm
var chain = []
for i in range(3):
    var joint_data = IKSolver.create_joint_data(
        get_node("Joint%d" % i),
        Vector3(0, 1, 0),  # Y-axis
        -PI/2, PI/2
    )
    chain.append(joint_data)

# Solve for target
var solver = AnalyticalIKSolver.new()
solver.initialize({})

if solver.solve(chain, Vector3(1, 0.5, 0)):
    # Apply rotations to joints
    IKSolver.apply_rotations(chain, solver.get_joint_rotations())
else:
    print("IK failed: ", solver.get_final_distance(), "m from target")
```

## Solver Configuration

### Iterations

More iterations = more accurate but slower:

```gdscript
solver.set_max_iterations(5)   # Fast, may not converge
solver.set_max_iterations(20)  # Accurate, slower
solver.set_max_iterations(50)  # Very accurate, slow
```

### Tolerance

Solver stops when closer than tolerance:

```gdscript
solver.set_tolerance(0.01)   # 1cm accuracy
solver.set_tolerance(0.001)   # 1mm accuracy
solver.set_tolerance(0.0001)  # 0.1mm accuracy
```

### Rotation Constraints

Limit which axes joints can rotate:

```gdscript
solver.set_rotation_constraints(true, true, false)  # Only X and Y
```

## When to Use Which

| Scenario | Recommended Solver |
|---------|-------------------|
| Simple robot arm (3-6 joints) | Analytical CCD |
| Tentacle/worm chain | Analytical FABRIK |
| Natural motion | Analytical FABRIK |
| Complex multi-chain robot | MoveIt |
| Collision-aware IK | MoveIt |
| Speed critical | Analytical CCD |
| Industry deployment | MoveIt |

## Performance Tips

### Analytical IK
- Use fewer iterations for real-time
- Simplify chains when possible
- Pre-calculate joint axes

### MoveIt
- Increase timeout for complex robots
- Use cached IK when solving repeatedly
- Configure MoveIt solver parameters

## Adding New Solvers

Implement the `IKSolver` interface:

```gdscript
class_name MyIKSolver
extends IKSolver

func solve(chain: Array, target: Vector3) -> bool:
    # Your IK implementation
    return true

# ... implement all required methods
```

Register in `IKSelector`:
```gdscript
_add_solver_option("MySolver", "My IK Engine", "Description", MySolver.is_available())
```

## Architecture

```
scripts/ik/
├── ik_solver.gd              # Abstract interface
├── analytical_ik_solver.gd   # CCD + FABRIK implementations
├── moveit_ik_bridge.gd      # ROS2/MoveIt bridge
├── moveit_bridge.py           # Python ROS2 node
└── ik_selector.gd           # Solver selection UI
```

---

**Tip:** Start with Analytical IK for fast iteration, switch to MoveIt when you need industry-grade accuracy for complex robots.
