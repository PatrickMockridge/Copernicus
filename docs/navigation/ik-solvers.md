# IK Solvers

Inverse Kinematics (IK) computes joint angles to reach a target position or orientation.

---

## Available Solvers

| Solver | Type | ROS 2 Required | Use Case |
|--------|------|---------------|----------|
| **CCD** | Analytical/iterative | No | Fast, simple chains |
| **FABRIK** | Analytical/iterative | No | Natural motion |
| **MoveIt** | ROS 2 service | Yes | Industry-grade |

---

## IK Problem Formulation

Given:
- Robot kinematic chain (links + joints)
- Target end-effector position

Find:
- Joint angles that place end-effector at target

```
Target (x, y, z)
    │
    ▼
IK Solver
    │
    ▼
Joint Angles [θ₁, θ₂, θ₃, ...]
```

---

## CCD (Cyclic Coordinate Descent)

Iteratively adjusts each joint to minimize end-effector error.

### Algorithm

```
1. For each iteration:
   a. Start from last joint (end-effector)
   b. For joint in reversed(chain):
      - Compute rotation to bring EE closer to target
      - Apply rotation
      - Update end-effector position
   c. If error < threshold: done
```

### Implementation

```gdscript
class_name AnalyticalIKSolver

func solve_ccd(chain: Array, target: Vector3, max_iterations: int = 20) -> bool:
    for iteration in range(max_iterations):
        # Iterate from end to base
        for i in range(chain.size() - 1, -1, -1):
            var joint = chain[i]
            var ee_pos = get_end_effector_position()

            # Vector from joint to EE
            var to_ee = ee_pos - joint.global_position
            # Vector from joint to target
            var to_target = target - joint.global_position

            # Compute rotation to align
            var rotation = align_vectors(to_ee, to_target)

            # Apply rotation to joint around its axis
            joint.rotate_joint(rotation)

        # Check convergence
        if ee_pos.distance_to(target) < 0.01:
            return true

    return false
```

### Pros/Cons

| Pros | Cons |
|------|------|
| Fast convergence for short chains | May not converge for long chains |
| Simple implementation | Can find local minima |
| Works well for 2-4 joints | No consideration of joint limits |

---

## FABRIK (Forward And Backward Reaching IK)

Uses a "reach and adjust" approach with forward and backward passes.

### Algorithm

```
1. Forward pass (from base to EE):
   - Move EE toward target
   - Propagate back through chain, adjusting each joint

2. Backward pass (from EE to base):
   - Constrain joints to reachable distances
   - Propagate constraints back to base

3. Repeat until convergence
```

### Implementation

```gdscript
func solve_fabrik(chain: Array, target: Vector3, max_iterations: int = 20,
                  tolerance: float = 0.01):
    # Compute link lengths
    var lengths = []
    for i in range(chain.size() - 1):
        lengths.append(chain[i].position.distance_to(chain[i + 1].position))

    for iteration in range(max_iterations):
        # Forward pass
        var ee_pos = chain[-1].global_position
        chain[-1].global_position = target  # Move EE to target

        for i in range(chain.size() - 2, -1, -1):
            var direction = (chain[i + 1].global_position - chain[i].global_position).normalized()
            chain[i].global_position = chain[i + 1].global_position - direction * lengths[i]

        # Backward pass
        chain[0].global_position = original_base_position

        for i in range(chain.size() - 1):
            var direction = (chain[i + 1].global_position - chain[i].global_position).normalized()
            chain[i + 1].global_position = chain[i].global_position + direction * lengths[i]

        # Check convergence
        if chain[-1].global_position.distance_to(target) < tolerance:
            return true

    return false
```

### Pros/Cons

| Pros | Cons |
|------|------|
| Natural joint motion | Requires full chain visibility |
| Good convergence properties | More complex than CCD |
| Handles joint constraints | Slower than CCD for short chains |

---

## MoveIt Bridge

Industry-grade IK via ROS 2 MoveIt service.

### When to Use

- Manipulator arms with 6+ DOF
- Collision-aware IK (avoid obstacles)
- Multi-robot coordination
- Integration with ROS 2 planning scene

### Requirements

```bash
# Install MoveIt
sudo apt install ros-jazzy-moveit

# Ensure robot_description is available
ros2 param set /robot_state_publisher robot_description "..."
```

### Basic Usage

```gdscript
var moveit = MoveItIKBridge.new()
moveit.initialize({
    "robot_description": "robot_description",
    "group_name": "manipulator",
    "timeout": 0.5
})


func solve_ik_for_target(target_pos: Vector3) -> Array:
    var chain = get_robot_chain()

    var result = moveit.solve(chain, target_pos)

    if result["status"] == "ok":
        return result["joint_positions"]

    return []  # IK failed
```

### Collision-Aware IK

```gdscript
moveit.configure({
    "avoid_collisions": true,
    "max_attempts": 10,
    "constraintaware": true
})

# Add obstacles to planning scene
moveit.add_collision_box("table", {
    "position": [0.5, 0, 0],
    "size": [1.0, 0.8, 0.05]
})

# Solve with collision avoidance
var solution = moveit.solve_with_collision(chain, target_pos)
```

---

## Joint Limits

Both CCD and FABRIK should respect joint limits:

```gdscript
class_name JointLimitedSolver

var _joint_limits: Dictionary = {}


func configure_limits(limits: Dictionary):
    _joint_limits = limits


func apply_limits(joint: Node3D):
    var joint_name = joint.name

    if _joint_limits.has(joint_name):
        var limit = _joint_limits[joint_name]

        if joint is PinJoint3D:
            joint.rotation = clamp(joint.rotation,
                                   limit["min"],
                                   limit["max"])

        elif joint is SliderJoint3D:
            joint.position.x = clamp(joint.position.x,
                                    limit["min"],
                                    limit["max"])


func solve_with_limits(chain: Array, target: Vector3) -> bool:
    var solved = solve_ccd(chain, target)

    if solved:
        for joint in chain:
            apply_limits(joint)

    return solved
```

---

## Selector Panel

```bash
godot scenes/ik_selector.tscn
```

Programmatically:

```gdscript
var available = IKSelector.get_available_solvers()
# Returns: ["AnalyticalIKSolver", "MoveItIKBridge"]

var solver = IKSelector.create_solver("AnalyticalIKSolver", {
    "algorithm": "CCD"
})
```

---

## Common Issues

### IK Not Converging

- Target out of reach — check `target.distance_to(base_position) < max_reach`
- Joint limits too restrictive
- Chain has singularity (fully stretched)

### MoveIt Connection Fails

- Verify ROS 2 is sourced
- Check `/compute_ik` service is available: `ros2 service list | grep ik`
- Ensure `robot_description` parameter is set

### Robot Looks "Wrong"

- Joint axis definitions may be incorrect in URDF
- Check parent-child chain matches physical robot
- Verify joint direction conventions

---

## Example: 4-DOF Arm

```gdscript
func solve_arm_ik():
    var chain = [
        get_node("base_joint"),    # Rotation (Z)
        get_node("shoulder_joint"), # Elevation (Y)
        get_node("elbow_joint"),    # Bend (Y)
        get_node("wrist_joint")     # Roll (X)
    ]

    var solver = AnalyticalIKSolver.new()
    solver.set_algorithm(solver.CCD)

    var target = Vector3(0.3, 0.2, 0.1)

    if solver.solve(chain, target):
        print("IK solved!")
        for joint in chain:
            print("%s: %.3f" % [joint.name, get_joint_angle(joint)])
    else:
        print("IK failed - target unreachable")
```

---

## Architecture

```
scripts/ik/
├── ik_solver.gd              # Abstract interface
├── analytical_ik_solver.gd   # CCD, FABRIK implementations
├── moveit_ik_bridge.gd       # MoveIt ROS 2 bridge
├── moveit_bridge.py          # Python side (subprocess)
└── ik_selector.gd           # Solver selection UI

scenes/
└── ik_selector.tscn         # Selector panel
```

---

## See Also

- [Navigation](planners.md) — Path planning to IK targets
- [URDF Import](../robots/urdf-import.md) — Robot model structure
- [Control](../robots/control.md) — Applying joint commands