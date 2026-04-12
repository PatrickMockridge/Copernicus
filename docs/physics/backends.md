# Physics Backends

Copernicus supports swappable physics backends, allowing you to choose the right
engine for your use case.

---

## Overview

```
Copernicus (Visualizer + Controller)
    │
    ├── Godot Native (VehicleBody3D) ← Fast, game-focused
    │       OR
    ├── PyBullet (Research Grade) ← Accurate, robotics-focused
    │       OR
    └── PyBullet CUDA (GPU) ← High-fidelity, GPU-accelerated
```

---

## Backend Comparison

| Backend | Speed | Accuracy | GPU | Use Case |
|---------|-------|----------|-----|----------|
| **Godot Native** | Very Fast | Game-grade | No | Design iteration, visualization |
| **PyBullet** | Medium | Research-grade | No | Manipulation, locomotion research |
| **PyBullet CUDA** | Fast | Research-grade | Yes | High-fidelity simulation |

---

## Godot Native

Uses Godot's built-in Jolt physics engine.

### When to Use

- Fast iteration during robot design
- Visualization without physics accuracy requirements
- Simple collision detection
- VehicleBody3D for wheeled robots

### Implementation

```gdscript
var backend = GodotPhysicsBackend.new()
backend.initialize({"gravity": Vector3(0, -9.81, 0)})
```

### Pros

- No external dependencies
- Very fast (60+ FPS)
- VehicleBody3D built-in
- Native Godot integration

### Cons

- Not research-grade accuracy
- Limited joint types
- Game-focused friction models
- No GPU acceleration

---

## PyBullet

Uses Bullet Physics via Python's PyBullet library.

### When to Use

- Manipulation research requiring accurate contact
- Locomotion analysis with realistic friction
- Industrial robot simulation
- When Godot accuracy is insufficient

### Requirements

```bash
pip install pybullet
```

### Implementation

```gdscript
var backend = PyBulletBackend.new()
backend.initialize({
    "gravity": Vector3(0, -9.81, 0),
    "timestep": 0.001
})

# Create bodies
backend.create_rigid_body("base", {
    "type": "box",
    "position": Vector3(0, 1, 0),
    "mass": 5.0
})

# Step simulation
backend.step_simulation(delta)
```

### Python Bridge Protocol

```json
// Init
{"cmd": "init", "gravity": [0, -9.81, 0], "timestep": 0.001}

// Create body
{"cmd": "create_body", "name": "base", "type": "box", "pos": [0, 1, 0], "mass": 5.0}

// Step
{"cmd": "step"}

// Get state
{"cmd": "get_state", "name": "base"}

// Apply force
{"cmd": "apply_force", "name": "base", "force": [10, 0, 0], "pos": [0, 0, 0]}

// Get contacts
{"cmd": "get_contacts", "name": "base"}

// Response
{"status": "ok", "data": {"pos": [0, 0.5, 0], "quat": [0, 0, 0, 1], "vel": [0, 0, 0]}}
```

### Pros

- Research-grade physics accuracy
- Industry-standard Bullet Physics
- Excellent for manipulation tasks
- Realistic contact modeling

### Cons

- Requires Python/PyBullet installed
- Slower than Godot native
- Subprocess communication overhead

---

## PyBullet CUDA

GPU-accelerated physics via PyBullet with CUDA.

### When to Use

- High-fidelity simulation requiring GPU speed
- Training RL policies with physics in the loop
- Complex environments with many bodies

### Requirements

```bash
pip install torch pybullet
# CUDA 11.8+ required
```

### Implementation

```gdscript
var backend = CUDAPhysics.new()
backend.initialize({
    "use_cuda": true,
    "gravity": Vector3(0, -9.81, 0)
})

# Check device
var device = backend.get_device()  # "cuda" or "cpu"
```

### Checking CUDA Availability

```gdscript
if GPUBackend.check_cuda_available():
    var backend = CUDAPhysics.new()
    backend.initialize({"use_cuda": true})
else:
    # Fallback to CPU
    var backend = PyBulletBackend.new()
    backend.initialize({})
```

### Pros

- GPU-accelerated rigid body dynamics
- Accurate joint constraints
- Contact point fidelity
- ~10x faster than CPU PyBullet

### Cons

- Requires NVIDIA GPU with CUDA
- More memory usage
- Setup complexity

---

## Backend Interface

All backends implement `PhysicsBackend`:

```gdscript
class_name PhysicsBackend
extends RefCounted

signal backend_initialized(success: bool)
signal backend_error(message: String)
signal simulation_stepped(delta: float)

static func is_available() -> bool
static func get_backend_name() -> String
static func get_backend_description() -> String

func initialize(config: Dictionary) -> bool
func shutdown()

## Simulation
func step_simulation(delta: float)
func is_running() -> bool

## Body Management
func create_rigid_body(name: String, config: Dictionary) -> bool
func remove_body(name: String)
func get_body_state(body_name: String) -> Dictionary
func get_all_states() -> Dictionary

## Forces
func apply_force(body_name: String, force: Vector3, position: Vector3 = Vector3.ZERO)
func apply_torque(body_name: String, torque: Vector3)
func reset_forces(body_name: String)

## Joints
func create_joint(name: String, config: Dictionary) -> bool
func remove_joint(name: String)

## Collision
func set_collision(body1: String, body2: String, enabled: bool)
func get_contacts(body_name: String) -> Array
```

---

## Switching Backends

You can switch backends at runtime:

```gdscript
func switch_physics_backend(backend_id: String) -> void:
    # Shutdown current
    if _current_backend:
        _current_backend.shutdown()

    # Create new backend
    match backend_id:
        "godot":
            _current_backend = GodotPhysicsBackend.new()
        "pybullet":
            _current_backend = PyBulletBackend.new()
        "cuda":
            _current_backend = CUDAPhysics.new()
        _:
            _current_backend = GodotPhysicsBackend.new()

    # Initialize
    _current_backend.initialize({})
```

---

## When to Use Which

| Scenario | Recommendation |
|----------|----------------|
| Quick design iteration | Godot Native |
| Visualizing robot motion | Godot Native |
| Testing control algorithms | Godot Native |
| Manipulation research | PyBullet or PyBullet CUDA |
| Accurate contact modeling | PyBullet or PyBullet CUDA |
| Locomotion analysis | PyBullet or PyBullet CUDA |
| RL training in simulation | PyBullet CUDA |
| Publishing to marketplace | Either (same API) |

---

## Performance Tips

### Godot Native

- Use simple collision shapes (boxes over meshes)
- Limit physics substeps for better FPS
- VehicleBody3D handles wheels efficiently

### PyBullet

- Reduce timestep if accuracy not critical: `timestep = 0.005`
- Batch state queries with `get_all_states()`
- Consider reducing solver iterations

### PyBullet CUDA

- Use batch operations when possible
- Keep body count manageable for GPU memory
- Consider LOD physics for distant objects

---

## Architecture

```
scripts/physics/
├── physics_backend.gd          # Abstract interface
├── godot_physics_backend.gd    # VehicleBody3D implementation
├── pybullet_backend.gd          # PyBullet subprocess bridge
├── pybullet_bridge.py           # Python side (subprocess)
└── physics_selector.gd          # UI for backend selection
```

---

## See Also

- [URDF Import](../robots/urdf-import.md) — Loading robot models
- [Sensors Overview](../sensors/overview.md) — Sensor simulation
- [Control](../robots/control.md) — Joint control systems