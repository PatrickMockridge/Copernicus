# GPU Acceleration

Copernicus supports GPU acceleration for physics simulation, reinforcement learning, and sensor processing via swappable backends.

## Overview

```
Copernicus (Robot Design Interface)
    │
    ├── GPU Backend Selection
    │   ├── PyBullet CUDA     → GPU-accelerated physics
    │   ├── PyTorch Q-Learning → Deep Q-Network (DQN) training
    │   └── GPU Raycast        → Batch LIDAR/camera processing
    │
    └── CPU Fallback (when GPU unavailable)
```

## Backend Comparison

| Backend | Speed | Use Case | Requirements |
|---------|-------|----------|--------------|
| **PyBullet CUDA** | GPU | High-fidelity robot simulation | NVIDIA GPU, CUDA, PyBullet |
| **PyTorch Q-Learning** | GPU | Autonomous skill acquisition | NVIDIA GPU, CUDA, PyTorch |
| **GPU Raycast** | GPU | LIDAR/camera sensor acceleration | NVIDIA GPU, CUDA, PyTorch |
| **CPU Fallback** | Slow | Development/testing | None |

## Why GPU Acceleration?

GPU acceleration enables Copernicus to compete with NVIDIA Isaac Gym for robot learning tasks:

| Feature | CPU | GPU (CUDA) |
|---------|-----|------------|
| Physics simulation | ~1x | ~10x faster |
| Neural network training | ~1x | ~50x faster |
| Batch raycasting (360°) | ~20ms | ~1ms |

## PyBullet CUDA

GPU-accelerated physics via PyBullet with CUDA support.

**Requirements:**
```bash
pip install torch pybullet
```

**Features:**
- GPU-accelerated rigid body dynamics
- Accurate joint constraints
- Contact point fidelity for manipulation research

**Usage:**
```gdscript
var backend = GPUBackendSelector.create_backend("CUDAPhysics", {
    "use_cuda": true
})
backend.step_simulation(delta)
```

## PyTorch Q-Learning

Deep Q-Network (DQN) reinforcement learning via PyTorch with CUDA.

**Requirements:**
```bash
pip install torch
```

**Features:**
- 3-layer DQN (128 hidden units)
- Experience replay buffer (10,000 entries)
- Epsilon-greedy exploration
- Automatic CUDA device detection

**Architecture:**
```
Input (state_dim)
    ↓
fc1: Linear → ReLU
    ↓
fc2: Linear → ReLU
    ↓
fc3: Linear → Q-values (action_dim)
```

**Usage:**
```gdscript
var learner = PyTorchLearner.new()
learner.initialize({
    "state_dim": 24,      # Sensor observations
    "action_dim": 4,      # Discrete actions
    "hidden_dim": 128,
    "device": "cuda"
})

# Training loop
var action = learner.get_action(observations)
apply_action(action)
var result = learner.train_step([obs], [action], [reward])

# Save/load policy
learner.save_model("policy.pt")
learner.load_model("policy.pt")
```

**Python Subprocess Protocol:**
```json
{"cmd": "init", "state_dim": 24, "action_dim": 4}
{"cmd": "train_step", "observations": [[...]], "actions": [0], "rewards": [1.0]}
{"cmd": "get_action", "observations": [[...]]}
{"cmd": "save_model", "path": "policy.pt"}
{"cmd": "shutdown"}
```

## GPU Raycast

GPU-accelerated batch raycasting for LIDAR and camera sensors.

**Requirements:**
```bash
pip install torch
```

**Features:**
- Batch raycast processing on GPU
- LIDAR sweep simulation (360°)
- Camera depth computation
- Configurable noise injection

**Usage:**
```gdscript
var raycaster = ComputeRaycast.new()
raycaster.initialize({
    "max_distance": 30.0,
    "noise_stddev": 0.0,
    "device": "cuda"
})

var directions = [
    Vector3.FORWARD,
    Vector3.BACK,
    Vector3.LEFT,
    Vector3.RIGHT
]
var ranges = raycaster.batch_raycast(origin, directions)
# returns: [12.5, 8.3, 15.0, 30.0]
```

## GPU Backend Selector

UI panel for selecting GPU acceleration backends:

```bash
godot scenes/gpu/gpu_backend_selector.tscn
```

**Programmatic selection:**
```gdscript
var selector = GPUBackendSelector.new()
var backend = GPUBackendSelector.create_backend("PyTorchLearner", config)
```

## Backend Interface

All GPU backends implement `GPUBackend`:

```gdscript
class_name GPUBackend
extends RefCounted

signal backend_ready()
signal backend_error(message: String)
signal training_step(loss: float)
signal episode_complete(reward: float)

static func is_available() -> bool
static func get_backend_name() -> String
func initialize(config: Dictionary) -> bool
func shutdown()

## Physics
func step_simulation(delta: float)

## Learning
func train_step(observations: Array, actions: Array, rewards: Array) -> Dictionary
func get_action(observations: Array) -> int
func save_model(path: String) -> bool
func load_model(path: String) -> bool

## Sensors
func batch_raycast(origin: Vector3, directions: Array) -> Array
```

## Performance Tips

### CUDA Availability
Check before creating backends:
```gdscript
if GPUBackend.check_cuda_available():
    var gpu_backend = CUDAPhysics.new()
```

### Batch Operations
Group sensor readings for GPU efficiency:
```gdscript
# Slow: individual raycasts
for ray in lidar_rays:
    var dist = raycast_single(origin, ray)

# Fast: batch raycast
var dists = raycaster.batch_raycast(origin, lidar_rays)
```

### Memory Management
Save model checkpoints periodically:
```gdscript
if steps % 1000 == 0:
    learner.save_model("checkpoint_%d.pt" % steps)
```

## Adding New Backends

Implement the `GPUBackend` interface:

```gdscript
class_name MyGPUBackend
extends GPUBackend

func initialize(config: Dictionary) -> bool:
    # Initialize GPU resources
    return true

func train_step(observations: Array, actions: Array, rewards: Array) -> Dictionary:
    # Run on GPU
    return {"loss": 0.0, "done": false}
```

Register in `GPUBackendSelector`:
```gdscript
_add_backend_option("MyBackend", "My GPU Backend", "Description", MyBackend.is_available())
```

## Architecture

```
scripts/gpu/
├── gpu_backend.gd              # Abstract interface
├── gpu_backend_selector.gd     # Selection UI
├── backends/
│   ├── cuda_physics.gd         # PyBullet CUDA physics
│   ├── pytorch_learner.gd       # PyTorch DQN learning
│   └── compute_raycast.gd       # GPU raycasting
├── ui/
│   └── learning_panel.gd        # RL training panel
└── pytorch_learning_node.py     # Python RL subprocess
```

## See Also

- [Physics Backends](physics-backends.md) — CPU physics alternatives
- [AI Code Agent](ai-codegen.md) — AI behavior generation
- [Marketplace](marketplace.md) — Trade learned policies

---

**Tip:** Start with CPU fallback for development, switch to GPU backends when you're ready for training runs.