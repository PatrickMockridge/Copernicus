# Physics Backends

Copernicus supports swappable physics backends, allowing you to choose the right physics engine for your use case.

## Overview

```
Copernicus (Visualizer + Controller)
    │
    ├── Godot Native (VehicleBody3D) ← Fast, game-focused
    │       OR
    └── PyBullet (Research Grade) ← Accurate, robotics-focused
```

## Backend Comparison

| Backend | Accuracy | Speed | Use Case |
|---------|----------|-------|----------|
| **Godot Native** | Game-grade | Very Fast | Design iteration, visualization |
| **PyBullet** | Research-grade | Slower | Manipulation, locomotion, research |

## Why Multiple Backends?

Godot's native physics (Jolt) is optimized for **games**, not robotics:

- Fast collision detection for real-time rendering
- VehicleBody3D for game-style vehicles
- Simplified friction/torque models

PyBullet provides **research-grade** accuracy:

- Accurate joint limits and constraints
- Realistic friction models
- Industrial robot compatibility
- Contact point fidelity

## Godot Native (Default)

Uses Godot's built-in Jolt physics engine.

**Pros:**
- No external dependencies
- Very fast (60+ FPS)
- VehicleBody3D built-in
- Native Godot integration

**Cons:**
- Not research-grade accuracy
- Limited joint types
- Game-focused friction models

```gdscript
var backend = GodotPhysicsBackend.new()
backend.initialize({"gravity": Vector3(0, -9.81, 0)})
```

## PyBullet (Research Grade)

Uses Bullet Physics via Python's PyBullet library.

**Requirements:**
```bash
pip install pybullet
```

**Pros:**
- Research-grade physics accuracy
- Industry-standard Bullet Physics
- Excellent for manipulation tasks
- Realistic contact modeling

**Cons:**
- Requires Python/PyBullet installed
- Slower than Godot native
- Subprocess communication overhead

```gdscript
var backend = PyBulletBackend.new()
backend.initialize({"gravity": Vector3(0, -9.81, 0)})
```

### PyBullet Bridge Protocol

The PyBullet backend communicates with a Python subprocess via JSON:

**Commands:**
```json
{"cmd": "init", "gravity": [0, -9.81, 0], "timestep": 0.001}
{"cmd": "create_body", "name": "base", "type": "box", "pos": [0, 1, 0], "mass": 5.0}
{"cmd": "step"}
{"cmd": "get_state", "name": "base"}
{"cmd": "apply_force", "name": "wheel", "force": [0, 0, 10]}
{"cmd": "shutdown"}
```

**Responses:**
```json
{"status": "ok", "cmd": "step"}
{"status": "ok", "cmd": "get_state", "pos": [0, 0.5, 0], "quat": [0, 0, 0, 1]}
```

## Backend Interface

All backends implement `PhysicsBackend`:

```gdscript
class_name PhysicsBackend

func initialize(config: Dictionary) -> bool
func step_simulation(delta: float)
func get_body_state(body_name: String) -> Dictionary
func create_rigid_body(name: String, config: Dictionary) -> bool
func apply_force(body_name: String, force: Vector3, position: Vector3)
func shutdown()
```

## Using the Physics Selector

Open the physics selector panel:

```bash
godot scenes/physics_selector.tscn
```

Select your desired backend and click **Apply**.

## Programmatic Backend Selection

```gdscript
# Get available backends
var available = PhysicsSelector.get_available_backends()

# Create a specific backend
var backend = PhysicsSelector.get_backend_class("PyBulletBackend")
backend.initialize({"gravity": Vector3(0, -9.81, 0)})

# Use it...
backend.create_rigid_body("base", {
    "type": "box",
    "position": Vector3(0, 1, 0),
    "mass": 5.0
})
```

## Switching Backends at Runtime

You can switch backends during runtime:

```gdscript
func switch_backend(backend_id: String):
    # Shutdown current backend
    current_backend.shutdown()

    # Create new backend
    current_backend = PhysicsSelector.get_backend_class(backend_id)
    current_backend.initialize({})

    # Recreate robot bodies
    for body in robot_bodies:
        current_backend.create_rigid_body(body.name, body.config)
```

## When to Use Which

| Scenario | Recommended Backend |
|---------|-------------------|
| Quick design iteration | Godot Native |
| Visualizing robot motion | Godot Native |
| Testing control algorithms | Godot Native |
| Manipulation research | PyBullet |
| Accurate contact modeling | PyBullet |
| Locomotion analysis | PyBullet |
| Publishing to marketplace | Either (same API) |

## Performance Tips

### Godot Native
- Use simple collision shapes (boxes over meshes)
- Limit physics substeps for better FPS
- VehicleBody3D handles wheels efficiently

### PyBullet
- Reduce timestep if accuracy not critical: `timestep = 0.005`
- Batch state queries with `get_all_states()`
- Consider reducing solver iterations

## Adding New Backends

Implement the `PhysicsBackend` interface:

```gdscript
class_name MyPhysicsBackend
extends PhysicsBackend

func initialize(config: Dictionary) -> bool:
    # Connect to your physics engine
    return true

func step_simulation(delta: float) -> void:
    # Step your physics
    pass

# ... implement all required methods
```

Register in `PhysicsSelector`:
```gdscript
_add_backend_option("MyBackend", "My Physics Engine", "Description", MyBackend.is_available())
```

## Architecture

```
scripts/physics/
├── physics_backend.gd          # Abstract interface
├── godot_physics_backend.gd    # VehicleBody3D implementation
├── pybullet_backend.gd          # PyBullet subprocess bridge
├── pybullet_bridge.py           # Python side (run as subprocess)
└── physics_selector.gd          # UI for backend selection
```

---

**Tip:** Start with Godot Native for fast iteration, switch to PyBullet when you need research-grade accuracy for your final validation.
