# DQN (Deep Q-Network)

DQN is a value-based reinforcement learning algorithm for discrete action spaces.

---

## How DQN Works

DQN learns a Q-function: `Q(state, action) → expected future reward`

```
State → Q-Network → Q-values for each action → Select action with highest Q
```

The network learns to predict: "If I'm in this state and take this action,
how much reward will I get over the rest of the episode?"

---

## Network Architecture

```python
class QNetwork(nn.Module):
    def __init__(self, state_dim, action_dim, hidden_dim=128):
        super().__init__()
        self.fc1 = nn.Linear(state_dim, hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, hidden_dim)
        self.fc3 = nn.Linear(hidden_dim, action_dim)

    def forward(self, x):
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        return self.fc3(x)
```

Input: State vector (e.g., 360 LIDAR ranges + robot pose = 362 dims)
Output: Q-value for each action (e.g., 4 for Forward/Back/Left/Right)

---

## Key Components

### Experience Replay

Store transitions in a buffer, sample randomly during training:

```python
class ReplayBuffer:
    def __init__(self, capacity=10000):
        self.buffer = []
        self.capacity = capacity
        self.position = 0

    def push(self, state, action, reward, next_state, done):
        if len(self.buffer) < self.capacity:
            self.buffer.append(None)
        self.buffer[self.position] = (state, action, reward, next_state, done)
        self.position = (self.position + 1) % self.capacity

    def sample(self, batch_size):
        return random.sample(self.buffer, batch_size)
```

Why? Breaks correlation between consecutive samples, stabilizes training.

### Target Network

Two networks: one learns, one provides stable targets:

```python
self.policy_net = QNetwork(state_dim, action_dim)
self.target_net = QNetwork(state_dim, action_dim)
self.target_net.load_state_dict(self.policy_net.state_dict())

# Periodically sync
if steps % target_update_freq == 0:
    self.target_net.load_state_dict(self.policy_net.state_dict())
```

Why? Without it, Q-values keep shifting, training oscillates or diverges.

---

## Training Step

```python
def train_step(self, observations, actions, rewards, gamma=0.99):
    # Sample from replay buffer
    batch = self.replay_buffer.sample(self.batch_size)

    # Compute current Q-values
    q_values = self.policy_net(states).gather(1, actions)

    # Compute target Q-values (using target network)
    with torch.no_grad():
        next_q = self.target_net(next_states).max(1)[0]
        target_q = rewards + (1 - dones) * gamma * next_q

    # Compute loss and update
    loss = F.mse_loss(q_values, target_q)
    self.optimizer.zero_grad()
    loss.backward()
    torch.nn.utils.clip_grad_norm_(self.policy_net.parameters(), 1.0)
    self.optimizer.step()

    return {"loss": loss.item()}
```

---

## Epsilon-Greedy Exploration

Balance exploration vs exploitation:

```python
def get_action(self, state, epsilon=0.1):
    if random.random() < epsilon:
        return random.randint(0, self.action_dim - 1)  # Explore
    else:
        with torch.no_grad():
            q_values = self.policy_net(state)
            return q_values.argmax().item()  # Exploit
```

Epsilon decays over time:

```python
self.epsilon = max(self.epsilon_min, self.epsilon * self.epsilon_decay)
# Start at 1.0, decay by 0.995 each step, minimum 0.01
```

---

## Copernicus Integration

### GDScript Side

```gdscript
var learner = PyTorchLearner.new()
learner.initialize({
    "state_dim": 362,
    "action_dim": 4,
    "device": "cuda" if GPUBackend.check_cuda_available() else "cpu"
})

# Training loop
func train_episode():
    var state = get_full_observation()
    var total_reward = 0.0

    for step in range(200):
        # Epsilon-greedy action
        var action = learner.get_action(state)

        # Apply to environment
        apply_action(action)

        # Get next observation
        var next_state = get_full_observation()
        var reward = compute_reward()

        # Train
        learner.train_step([state], [action], [reward])

        state = next_state
        total_reward += reward

    return total_reward
```

### Python Subprocess (pytorch_learning_node.py)

```python
class LearningNode:
    def __init__(self, state_dim, action_dim, hidden_dim=128, device="cpu"):
        self.policy_net = QNetwork(state_dim, action_dim, hidden_dim).to(device)
        self.target_net = QNetwork(state_dim, action_dim, hidden_dim).to(device)
        self.replay_buffer = ReplayBuffer(capacity=10000)
        self.epsilon = 1.0

    def train_step(self, observations, actions, rewards, gamma=0.99):
        # Add to replay buffer
        for i in range(len(observations)):
            self.replay_buffer.push(observations[i], actions[i],
                                      rewards[i], observations[i], False)

        if len(self.replay_buffer) < self.batch_size:
            return {"status": "ok", "loss": 0.0}

        # Sample and train
        batch = self.replay_buffer.sample(self.batch_size)
        # ... training logic

        return {"status": "ok", "loss": loss.item()}
```

---

## Hyperparameters

| Parameter | Typical Value | Notes |
|-----------|---------------|-------|
| learning_rate | 0.001 | ADAM optimizer |
| batch_size | 64 | Sample size from replay |
| gamma | 0.99 | Discount factor |
| epsilon_start | 1.0 | Initial exploration |
| epsilon_min | 0.01 | Final exploration |
| epsilon_decay | 0.995 | Per-step decay |
| replay_capacity | 10000 | Buffer size |
| target_update_freq | 100 | Steps between sync |

---

## When to Use DQN

### Good For

- Discrete action spaces (left/right, go/stop)
- Single-agent learning
- Environments with frequent rewards
- When you need interpretable Q-values

### Not Ideal For

- Continuous actions (use PPO/SAC)
- Multi-agent scenarios (use MA3QN)
- Sparse rewards (use curiosity-based methods)
- Real-time requirements (Q-value computation adds latency)

---

## Example: Navbot Navigation

```gdscript
func train_navbot_dqn():
    var learner = PyTorchLearner.new()
    learner.initialize({
        "state_dim": 362,  # 360 LIDAR + x, y position
        "action_dim": 4,   # Forward, Back, Left, Right
        "device": "cuda"
    })

    for episode in range(500):
        var state = get_lidar_and_position()
        var episode_reward = 0

        for step in range(300):
            # Get action from DQN
            var action = learner.get_action(state)

            # Map to movement
            match action:
                0: move_forward()
                1: move_backward()
                2: turn_left()
                3: turn_right()

            # Get feedback
            var next_state = get_lidar_and_position()
            var reward = -0.01 if step < 300 else 100.0 if at_goal else -1.0

            # Train
            learner.train_step([state], [action], [reward])

            state = next_state
            episode_reward += reward

            if at_goal:
                break

        print("Episode %d: reward=%.1f, eps=%.3f" %
              [episode, episode_reward, learner.get_epsilon()])
```

---

## See Also

- [RL Overview](overview.md) — RL introduction
- [PPO/SAC](ppo-sac.md) — Policy gradient methods
- [GPU Acceleration](../gpu-acceleration.md) — Backend details