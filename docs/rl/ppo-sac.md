# PPO and SAC

PPO (Proximal Policy Optimization) and SAC (Soft Actor-Critic) are policy gradient methods
for continuous action spaces.

---

## Why Policy Gradient?

DQN outputs Q-values for discrete actions. But robots need continuous control:
- Torque commands (joint efforts)
- Velocity commands (wheel RPMs)
- Position targets (end-effector goals)

Policy gradient methods directly output actions, enabling continuous control.

---

## PPO: Proximal Policy Optimization

PPO is an on-policy algorithm that limits how much the policy changes per update.

### Core Idea

```python
# Old policy vs new policy
ratio = pi_new(a|s) / pi_old(a|s)

# Clipped objective prevents too-large updates
clipped_ratio = clamp(ratio, 1 - epsilon, 1 + epsilon)
loss = -min(ratio * advantage, clipped_ratio * advantage)
```

This "clipped" objective prevents the policy from changing too drastically,
leading to more stable training.

### Actor-Critic Architecture

```python
class ActorCritic(nn.Module):
    def __init__(self, state_dim, action_dim, hidden_dim=128):
        self.actor = nn.Sequential(
            nn.Linear(state_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, action_dim)
        )
        self.critic = nn.Sequential(
            nn.Linear(state_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 1)
        )
```

Actor: policy (what action to take)
Critic: value function (how good is this state)

### PPO Update

```python
def ppo_update(self, states, actions, old_log_probs, advantages, gamma=0.99,
               epsilon_clip=0.2, update_epochs=10):
    for _ in range(update_epochs):
        # Get current policy outputs
        action_logits, values = self.policy(states)
        dist = torch.distributions.Categorical(F.softmax(action_logits, dim=-1))
        new_log_probs = dist.log_prob(actions)
        entropy = dist.entropy().mean()

        # Compute ratio
        ratio = torch.exp(new_log_probs - old_log_probs)

        # Clipped objective
        surr1 = ratio * advantages
        surr2 = clamp(ratio, 1 - epsilon_clip, 1 + epsilon_clip) * advantages
        policy_loss = -torch.min(surr1, surr2).mean()

        # Entropy bonus (encourages exploration)
        entropy_loss = -0.01 * entropy

        # Total loss
        loss = policy_loss + entropy_loss

        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

    return {"loss": loss.item(), "entropy": entropy}
```

### When to Use PPO

- Continuous action spaces
- Stable training required
- When you need sample-efficient on-policy learning
- Manipulation, locomotion, whole-body control

---

## SAC: Soft Actor-Critic

SAC is an off-policy algorithm with entropy regularization.

### Core Idea

Maximize expected return + entropy bonus:
```
objective = E[Q(s,a)] + alpha * H(pi)
```

Higher entropy = more exploration. The temperature parameter `alpha`
controls the exploration-exploitation tradeoff.

### Automatic Temperature Tuning

```python
# SAC automatically adjusts alpha
self.log_alpha = torch.tensor([math.log(0.2)], requires_grad=True)
self.alpha_opt = optim.Adam([self.log_alpha], lr=0.0003)

# In training:
alpha = self.log_alpha.exp()
actor_loss = -(q_values + alpha * log_probs).mean()
alpha_loss = (self.log_alpha * (log_probs + target_entropy)).mean()

self.alpha_opt.zero_grad()
alpha_loss.backward()
self.alpha_opt.step()
```

### SAC Update

```python
def sac_update(self, states, actions, rewards, next_states, dones, gamma=0.99):
    # Update Q networks
    with torch.no_grad():
        next_action_logits = self.actor(next_states)
        next_probs = F.softmax(next_action_logits, dim=-1)
        next_log_probs = torch.log(next_probs + 1e-8)
        next_q = min(self.target_q1(next_states, next_probs),
                     self.target_q2(next_states, next_probs))
        target_q = rewards + gamma * (1 - dones) * next_q

    # Q loss
    q1_loss = F.mse_loss(self.q1(states, actions), target_q)
    q2_loss = F.mse_loss(self.q2(states, actions), target_q)
    q_loss = q1_loss + q2_loss

    self.q_opt.zero_grad()
    q_loss.backward()
    self.q_opt.step()

    # Actor loss
    action_logits = self.actor(states)
    probs = F.softmax(action_logits, dim=-1)
    log_probs = torch.log(probs + 1e-8)
    q_values = min(self.q1(states, probs), self.q2(states, probs))
    actor_loss = -(q_values + alpha * log_probs).mean()

    self.actor_opt.zero_grad()
    actor_loss.backward()
    self.actor_opt.step()

    # Soft update target network
    self.soft_update(self.target_q1, self.q1, tau=0.005)
    self.soft_update(self.target_q2, self.q2, tau=0.005)
```

### When to Use SAC

- Continuous action spaces
- Sparse rewards (entropy helps exploration)
- Off-policy data collection (can reuse old data)
- Sample-efficient learning

---

## PPO vs SAC Comparison

| Aspect | PPO | SAC |
|--------|-----|-----|
| Policy type | On-policy | Off-policy |
| Exploration | ε-greedy / entropy | Entropy maximization |
| Update method | Clipped surrogate | Soft Q-learning |
| Sample efficiency | Lower (throws away data) | Higher (reuses data) |
| Hyperparameter sensitivity | Lower | Higher |
| Continuous control | ✓ | ✓ |
| Discrete actions | ✓ (via softmax) | ✓ (via softmax) |

**Use PPO when:**
- You need stable, reliable training
- Sample efficiency is not critical
- You're doing on-policy simulation

**Use SAC when:**
- You can collect lots of data
- Rewards are sparse (need more exploration)
- You want state-of-the-art sample efficiency

---

## Copernicus Integration

### PPO GDScript

```gdscript
var learner = PPOLearner.new()
learner.initialize({
    "state_dim": 24,
    "action_dim": 3,  # x, y, z torques
    "epsilon_clip": 0.2,
    "device": "cuda"
})

func train():
    for episode in range(500):
        var state = get_observations()
        var episode_reward = 0.0

        for step in range(200):
            var result = learner.get_action(state)
            var action = result["action"]
            var log_prob = result["log_prob"]
            var value = result["value"]

            apply_torques(action)
            var next_state = get_observations()
            var reward = compute_reward()

            learner.train_step([state], [action], [reward], [log_prob], [value], [done])

            state = next_state
            episode_reward += reward
```

### SAC GDScript

```gdscript
var learner = SACLearner.new()
learner.initialize({
    "state_dim": 24,
    "action_dim": 3,
    "auto_alpha": true,
    "device": "cuda"
})

func train():
    for episode in range(500):
        var state = get_observations()
        var done = false

        while not done:
            var result = learner.get_action(state)
            var action = result["action"]

            var next_state = apply_continuous_action(action)
            var reward = compute_reward()

            # SAC needs next state for bootstrapping
            learner.train_step([state], [action], [reward],
                               [next_state], [done])

            state = next_state
```

---

## Common Issues

### PPO: Crashed or Diverged Loss

- Reduce learning rate
- Increase epsilon_clip
- Normalize observations
- Check reward scale (should be roughly -1 to 1)

### SAC: Entropy Collapse

- If entropy goes to 0 too fast, reduce automatic alpha tuning
- Increase initial alpha value
- Use fixed alpha initially, tune manually

### Both: Policy Just Repeats Same Action

- Increase entropy coefficient (0.01 → 0.1)
- Reduce learning rate
- Check that actions actually affect environment

---

## Hyperparameters

### PPO

| Parameter | Typical Value |
|-----------|---------------|
| learning_rate | 0.0003 |
| epsilon_clip | 0.2 |
| gae_lambda | 0.95 |
| update_epochs | 10 |
| mini_batch_size | 64 |
| gamma | 0.99 |

### SAC

| Parameter | Typical Value |
|-----------|---------------|
| learning_rate | 0.0003 |
| gamma | 0.99 |
| tau (soft update) | 0.005 |
| auto_alpha | true |
| target_entropy | -action_dim |

---

## Example: Robotic Manipulation

```gdscript
func train_reach():
    var learner = PPOlearner.new()  # PPO is often better for manipulation
    learner.initialize({
        "state_dim": 18,  # ee_pos(3) + joint_angles(6) + target_pos(3) + ee_vel(3) + force(3)
        "action_dim": 6,   # 6 joint torques
        "device": "cuda"
    })

    for episode in range(1000):
        var state = get_full_observation()
        var episode_reward = 0.0

        for step in range(500):
            var result = learner.get_action(state)
            var torques = decode_torques(result["action"])

            apply_joint_torques(torques)

            var next_state = get_full_observation()
            var reward = compute_reach_reward()

            learner.train_step([state], [result["action"]], [reward],
                              [result["log_prob"]], [result["value"]], [done])

            state = next_state
            episode_reward += reward

            if episode_reward > 1000:
                break

        print("Episode %d: reward=%.1f" % [episode, episode_reward])
```

---

## See Also

- [RL Overview](overview.md) — RL introduction
- [DQN](dqn.md) — Discrete action algorithm
- [Control](../robots/control.md) — Using learned policies in robot control