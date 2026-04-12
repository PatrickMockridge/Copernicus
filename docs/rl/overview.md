# Reinforcement Learning Overview

Copernicus supports reinforcement learning (RL) for autonomous robot skill acquisition
using GPU-accelerated PyTorch backends.

---

## What is Reinforcement Learning?

RL is learning from experience:

```
Agent (Robot) → State → Action → Environment → Reward → State
                    ↑                              │
                    └──── Learn from feedback ←───┘
```

**Key loop:**
1. **Observe** state of the world
2. **Act** based on policy
3. **Receive** reward (or penalty)
4. **Learn** to maximize cumulative reward

---

## RL Components

### Agent (Policy)
The robot's decision-making algorithm:
- **DQN**: Discrete actions (go left/right/up/down)
- **PPO**: Continuous actions (torque outputs)
- **SAC**: Continuous actions with entropy exploration

### Environment (Copernicus)
The physics simulation:
- Robot dynamics via physics backend
- Sensor observations (LIDAR, camera, IMU)
- Contact detection (manipulation tasks)

### Reward Function
Defines what to learn:
```gdscript
func compute_reward(robot_pos: Vector3, goal_pos: Vector3) -> float:
    var distance = robot_pos.distance_to(goal_pos)
    if distance < 0.5:
        return 100.0  # Goal reached!
    return -distance * 0.1  # Penalize distance
```

---

## Supported Algorithms

| Algorithm | Action Space | Exploration | Use Case |
|-----------|-------------|-------------|----------|
| **DQN** | Discrete | ε-greedy | Navigation (discrete moves) |
| **PPO** | Continuous | On-policy | Manipulation, locomotion |
| **SAC** | Continuous | Entropy bonus | Sparse rewards, exploration |

### DQN (Deep Q-Network)

Value-based method for discrete actions:

```gdscript
var learner = PyTorchLearner.new()
learner.initialize({
    "state_dim": 24,      # e.g., 360 LIDAR rays + robot state
    "action_dim": 4,       # 4 discrete actions (F/B/L/R)
    "device": "cuda"
})

# In training loop
var state = get_observations()
var action = learner.get_action(state)
apply_action(action)
var reward = compute_reward()
learner.train_step([state], [action], [reward])
```

### PPO (Proximal Policy Optimization)

Policy gradient for continuous control:

```gdscript
var learner = PPOLearner.new()
learner.initialize({
    "state_dim": 24,
    "action_dim": 3,  # x, y, z torques
    "epsilon_clip": 0.2,
    "device": "cuda"
})

# Training
var result = learner.get_action(state)
var action = result["action"]
var log_prob = result["log_prob"]
apply_action(action)
var reward = compute_reward()
learner.train_step([state], [action], [rewards], [log_prob], [value], [done])
```

### SAC (Soft Actor-Critic)

Off-policy with entropy maximization:

```gdscript
var learner = SACLearner.new()
learner.initialize({
    "state_dim": 24,
    "action_dim": 3,
    "auto_alpha": true,  # Auto-tune exploration
    "device": "cuda"
})
```

---

## Training Loop

```gdscript
class_name RLTrainingLoop

var _learner: RefCounted
var _environment: Node3D
var _max_episodes: int = 1000


func train():
    for episode in range(_max_episodes):
        var state = _environment.reset()
        var episode_reward = 0.0
        var done = false

        while not done:
            # Get action from policy
            var action_result = _learner.get_action(state)
            var action = action_result["action"]

            # Apply to environment
            var next_state = _environment.step(action)
            var reward = _environment.compute_reward()

            # Train on experience
            _learner.train_step([state], [action], [reward])

            state = next_state
            episode_reward += reward

            if _environment.is_done():
                done = true

        print("Episode %d: reward = %.2f" % [episode, episode_reward])

        # Save checkpoint periodically
        if episode % 100 == 0:
            _learner.save_model("checkpoint_%d.pt" % episode)
```

---

## Observation Spaces

### LIDAR-Based

```gdscript
func get_lidar_observations(lidar: LidarSensor) -> Array:
    var ranges = lidar.get_ranges()
    # Normalize to [0, 1]
    return ranges.map(func(r): return r / lidar._range_max)
```

### Camera-Based

```gdscript
func get_camera_observations(camera: CameraSensor) -> Array:
    var image = camera.render_viewport()
    # Downsample to reduce state dimension
    return downsample(image, 32, 32)
```

### Multi-Modal

```gdscript
func get_full_observation() -> Array:
    var lidar_obs = get_lidar_observations(_lidar)
    var imu_obs = [_imu.get_linear_acceleration().x,
                   _imu.get_linear_acceleration().y,
                   _imu.get_angular_velocity().z]
    var joint_obs = get_joint_positions()
    return lidar_obs + imu_obs + joint_obs
```

---

## Reward Shaping

### Sparse Rewards (Hard)

```gdscript
# Only reward when goal is reached
func compute_reward():
    if robot.position.distance_to(goal) < 0.1:
        return 1.0
    return 0.0
```

### Dense Rewards (Easier to learn)

```gdscript
func compute_reward():
    var distance = robot.position.distance_to(goal)
    return -distance  # More negative as you get farther
```

### Shaped Dense Rewards

```gdscript
func compute_reward():
    var prev_distance = _robot.position.distance_to(_goal)
    var curr_distance = robot.position.distance_to(goal)

    # Reward for getting closer
    var distance_reward = prev_distance - curr_distance

    # Small reward for low velocity (encourage stability)
    var velocity_penalty = -robot.linear_velocity.length() * 0.01

    # Big reward for reaching goal
    var goal_reward = 100.0 if curr_distance < 0.1 else 0.0

    return distance_reward + velocity_penalty + goal_reward
```

---

## GPU Backend Selection

```gdscript
var selector = GPUBackendSelector.new()

# Check available backends
var available = GPUBackendSelector.get_available_backends()
print("Available: ", available)  # ["CUDAPhysics", "PyTorchLearner", "ComputeRaycast"]

# Create specific backend
var learner = GPUBackendSelector.create_backend("PyTorchLearner", {
    "state_dim": 24,
    "action_dim": 4,
    "device": "cuda"
})
```

---

## Metrics Dashboard

Track training progress:

```gdscript
var panel = LearningPanel.new()
panel.record_episode(reward, episode_count)
panel.record_metric("loss", loss_value)
panel.record_metric("entropy", policy_entropy)

# Get metrics for plotting
var metrics = panel.get_metrics()
var reward_history = metrics["reward_history"]
var loss_history = metrics["loss_history"]
```

---

## Common Training Issues

### Catastrophic Forgetting

If performance suddenly drops:
- Reduce learning rate
- Increase replay buffer size
- Check for reward hacking

### Never Converges

If no improvement:
- Check reward function
- Verify observations are informative
- Ensure action affects environment
- Increase network size

### Exploding Gradients

If loss becomes NaN:
- Reduce learning rate
- Clip gradients (PPO has built-in clipping)
- Normalize observations

---

## Example: Training a Navbot

```gdscript
func train_navbot():
    var learner = PyTorchLearner.new()
    learner.initialize({
        "state_dim": 362,  # 360 LIDAR + 2 robot pos
        "action_dim": 4,    # Forward, Back, Left, Right
        "device": "cuda" if GPUBackend.check_cuda_available() else "cpu"
    })

    for episode in range(500):
        var state = get_full_observation()
        var total_reward = 0.0

        for step in range(200):
            var action = learner.get_action(state)
            move_robot(action)

            var next_state = get_full_observation()
            var reward = compute_reward()

            learner.train_step([state], [action], [reward])

            state = next_state
            total_reward += reward

            if at_goal():
                break

        print("Episode %d: reward = %.2f, epsilon = %.3f" %
              [episode, total_reward, learner.get_epsilon()])

    learner.save_model("navbot_policy.pt")
```

---

## See Also

- [DQN](dqn.md) — Deep Q-Network implementation
- [PPO/SAC](ppo-sac.md) — Policy gradient methods
- [Control](../robots/control.md) — Using learned policies
- [GPU Acceleration](../gpu-acceleration.md) — GPU backend details