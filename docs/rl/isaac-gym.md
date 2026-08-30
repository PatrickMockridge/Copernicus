# Isaac Gym RL Tasks

GPU-accelerated reinforcement learning using NVIDIA Isaac Gym for multi-robot training with thousands of parallel environments.

Isaac Gym is one **experimental** RL backend, selected with `tool gpu` (spec 13).

---

## Overview

Isaac Gym provides high-performance GPU-based RL training by running thousands of robot simulations in parallel directly on the GPU. This enables rapid training of manipulation, locomotion, and control policies.

Copernicus integrates with Isaac Gym through:

| Component | Purpose |
|-----------|---------|
| `IsaacGymTask` | Base wrapper for Isaac Gym tasks |
| `IsaacGymReplicator` | Omniverse Replicator for synthetic data |
| `MultiRobotTrainer` | Distributed multi-robot training coordinator |

---

## IsaacGymTask

Pre-built RL environments for robotics tasks.

### Available Tasks

```gdscript
var task = IsaacGymTask.new()
var available = task.get_available_tasks()

for task_name in available:
    var desc = task.get_task_description(task_name)
    print(task_name, ": ", desc)
```

| Task | Description |
|------|-------------|
| `shadow_hand` | Dexterous hand manipulation - pick and place |
| `anymal` | Quadruped locomotion over rough terrain |
| `allegro_hand` | Shadow Hand-style dextrous manipulation |
| `cartpole` | Classic control - balance pole on cart |
| `ball_balance` | Robot eye-hand coordination |
| `quadcopter` | Multi-rotor flight control |
| `franka_cube` | Pick and place with Franka Panda arm |
| `kortex_robot` | Kinova Kortex arm manipulation |

### Initialization

```gdscript
var task = IsaacGymTask.new()

var config = {
    "task_name": "shadow_hand",
    "num_envs": 4096,      # Number of parallel environments
    "device": "cuda:0"      # GPU device
}

if task.initialize(config):
    print("Task initialized successfully")

    # Connect signals
    task.task_reset.connect(_on_task_reset)
    task.episode_complete.connect(_on_episode_complete)
    task.training_step.connect(_on_training_step)
```

### Training Loop

```gdscript
func train():
    # Reset environment
    var observations = task.reset()

    for step in range(10000):
        # Get actions from policy (DQN, PPO, SAC)
        var actions = policy.get_action(observations)

        # Step the simulation
        var result = task.step(actions)

        observations = result["observations"]
        var mean_reward = result["mean_reward"]

        if step % 100 == 0:
            print("Step: ", step, " Mean reward: ", mean_reward)
```

### Domain Randomization

```gdscript
# Enable dynamics randomization for sim-to-real transfer
task.set_dynamics_randomization(true)

# Add observation noise
task.set_observation_noise(0.01)

# Configure physics parameters
task.set_physics_parameters({
    "gravity": -9.81,
    "friction": 0.5,
    "restitution": 0.3
})
```

### GPU Memory Management

```gdscript
# Reset GPU buffers (call periodically to free memory)
task.reset_buffers()

# Enable/disable rendering
task.enable_rendering(false)
```

### Camera Images

```gdscript
# Get RGB/D camera images for specific environments
var images = task.get_camera_images([0, 1, 2, 3])

if images.has("rgb"):
    var rgb_data = images["rgb"]

if images.has("depth"):
    var depth_data = images["depth"]
```

---

## IsaacGymReplicator

Omniverse Replicator for synthetic data generation during training.

### Setup

```gdscript
var replicator = IsaacGymReplicator.new()

var config = {
    "enabled": true,
    "output_dir": "cache/replicator/",
    "capture_interval": 100,
    "capture_types": ["rgb", "depth", "semantic", "bounding_box"]
}

replicator.initialize(config)
```

### Annotators

```gdscript
# Create annotators for different data types
replicator.create_bounding_box_2d()
replicator.create_bounding_box_3d()
replicator.create_semantic_segmentation("schema.yaml")
```

### Cameras

```gdscript
# Setup cameras
var camera_config = {
    "count": 4,
    "resolution": [640, 480],
    "fov": 60.0
}
var cameras = replicator.setup_cameras(camera_config)

# Set camera poses
for i in range(4):
    replicator.set_camera_pose(i, Vector3(i * 0.5, 1.0, 0.5), Quaternion.IDENTITY)
```

### Domain Randomization

```gdscript
# Enable full domain randomization
replicator.enable_domain_randomization(true)

# Add specific randomization
replicator.add_color_randomization("object_color", 0.0, 1.0)
replicator.add_transform_randomization("object_pose", -0.1, 0.1)
replicator.add_light_randomization()
replicator.add_materials_randomization()
```

### Data Capture

```gdscript
# Capture single frame
var frame = replicator.capture_frame(env_id=0)

# Batch capture
var frames = replicator.batch_capture(100, [0, 1, 2, 3])

# Save annotations
replicator.save_annotations(frame_id=0, output_format="coco")
```

### SDF Integration

```gdscript
# Get SDF annotations
var sdf_data = replicator.get_sdf_annotations(env_id=0)

# Export to Isaac Sim
replicator.export_sdf_to_isaac("scene.sdf", "/tmp/isaac_scene.sdf")
```

### Writers

```gdscript
# Configure output writers
replicator.configure_writer("kittof", "dataset/kitti/", {"compression": true})
replicator.configure_writer("coco", "dataset/coco/", {"labels": ["robot", "object"]})
replicator.configure_writer("yolo", "dataset/yolo/", {"img_size": 640})

# Async recording
replicator.start_async_recording()
# ... training loop ...
replicator.stop_async_recording()
```

---

## MultiRobotTrainer

Coordinator for distributed multi-robot GPU training.

### Algorithms

```gdscript
var trainer = MultiRobotTrainer.new()

# PPO - Proximal Policy Optimization
# SAC - Soft Actor-Critic
# TD3 - Twin Delayed DDPG

var algorithms = trainer.get_supported_algorithms()
for algo in algorithms:
    print(algo, ": ", trainer.get_algorithm_description(algo))
```

### Initialization

```gdscript
var config = {
    "num_robots": 4,
    "algorithm": "PPO",
    "device": "cuda:0",
    "checkpoint_dir": "cache/checkpoints/",

    # PPO-specific
    "ppo_config": {
        "lr": 0.0003,
        "gamma": 0.99,
        "k_epochs": 4,
        "eps_clip": 0.2,
        "entropy_coef": 0.01
    },

    # SAC-specific
    "sac_config": {
        "lr": 0.0003,
        "gamma": 0.99,
        "tau": 0.005,
        "entropy_coef": 0.2
    }
}

trainer.initialize(config)
```

### Task Management

```gdscript
# Add multiple tasks (different robot types)
var shadow_task = IsaacGymTask.new()
shadow_task.initialize({"task_name": "shadow_hand", "num_envs": 2048})

var anymal_task = IsaacGymTask.new()
anymal_task.initialize({"task_name": "anymal", "num_envs": 2048})

trainer.add_task(shadow_task)
trainer.add_task(anymal_task)

# Get task by name
var task = trainer.get_task("shadow_hand")

# Remove task
trainer.remove_task("anymal")
```

### Training Control

```gdscript
# Connect signals
trainer.training_started.connect(_on_training_started)
trainer.training_stopped.connect(_on_training_stopped)
trainer.step_complete.connect(_on_step_complete)
trainer.episode_complete.connect(_on_episode_complete)
trainer.checkpoint_saved.connect(_on_checkpoint_saved)

# Start/stop training
trainer.start_training()
# ... training loop ...
trainer.stop_training()

# Pause/resume
trainer.pause_training()
trainer.resume_training()
```

### Training Loop

```gdscript
func _process(delta):
    if is_training:
        # Execute training step
        var result = trainer.train_step(delta)

        var mean_reward = result["mean_reward"]
        var done = result["done"]

        if done:
            print("Episode complete! Mean reward: ", mean_reward)
```

### Checkpointing

```gdscript
# Save checkpoint
var path = trainer.save_checkpoint("my_policy")

# Load checkpoint
trainer.load_checkpoint(path)

# Get checkpoint info
var info = trainer.get_checkpoint_info(path)
print("Step: ", info["step"], " Episodes: ", info["episodes"])
```

### Statistics

```gdscript
# Get training stats
var stats = trainer.get_training_stats()
print("Step: ", stats["current_step"])
print("Episodes: ", stats["total_episodes"])
print("Algorithm: ", stats["algorithm"])

# Get learning curve for plotting
var curve = trainer.get_learning_curve(100)

# Get reward history
var rewards = trainer.get_reward_history(100)
```

### Multi-Robot Coordination

```gdscript
# Synchronize robot states
trainer.synchronize_robots()

# Get specific robot state
var state = trainer.get_robot_state(robot_id=0)

# Set goal for a robot
trainer.set_robot_goal(0, {
    "position": Vector3(1.0, 0.5, 0.0),
    "orientation": Quaternion.IDENTITY
})
```

---

## GPU Backend Selector

Run the GPU backend selector scene to choose Isaac Gym tasks:

```bash
godot scenes/gpu/gpu_backend_selector.tscn
```

This provides a UI for:
- Selecting Isaac Gym task type
- Configuring number of environments
- Choosing training algorithm
- Setting domain randomization parameters

---

## Requirements

- NVIDIA Isaac Gym (installed with Omniverse)
- NVIDIA GPU with CUDA support
- Omniverse Replicator (optional, for synthetic data)

```bash
# Check Isaac Gym availability
python3 -c "import isaacgym; print('Isaac Gym available')"

# Check Omniverse Replicator
python3 -c "import omni.replicator; print('Replicator available')"
```

---

## See Also

- [PPO and SAC](ppo-sac.md) - RL algorithm details
- [GPU Raycasting](../gpu/rtx_sensors.md) - GPU-accelerated raycasting
- [Omniverse Integration](../omni/overview.md) - USD pipeline
- [RTX Sensors](../gpu/rtx_sensors.md) - GPU sensor simulation
