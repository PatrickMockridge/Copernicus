#!/usr/bin/env python3
# pytorch_learning_node.py
# PyTorch Q-learning subprocess for Copernicus GPU learning
# Provides DQN reinforcement learning with CUDA support

import sys
import json
import random
import math
import socket
import argparse
from typing import List, Tuple, Optional, Dict

try:
    import torch
    import torch.nn as nn
    import torch.optim as optim
    import torch.nn.functional as F
except ImportError:
    print(json.dumps({"status": "error", "message": "PyTorch not available"}))
    sys.exit(1)


class QNetwork(nn.Module):
    """Deep Q-Network for reinforcement learning"""

    def __init__(self, state_dim: int, action_dim: int, hidden_dim: int = 128):
        super().__init__()
        self.fc1 = nn.Linear(state_dim, hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, hidden_dim)
        self.fc3 = nn.Linear(hidden_dim, action_dim)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        return self.fc3(x)


class ReplayBuffer:
    """Experience replay buffer for DQN"""
    def __init__(self, capacity: int = 10000):
        self.buffer = []
        self.capacity = capacity
        self.position = 0

    def push(self, state, action, reward, next_state, done):
        if len(self.buffer) < self.capacity:
            self.buffer.append(None)
        self.buffer[self.position] = (state, action, reward, next_state, done)
        self.position = (self.position + 1) % self.capacity

    def sample(self, batch_size: int) -> List:
        return random.sample(self.buffer, min(batch_size, len(self.buffer)))

    def __len__(self) -> int:
        return len(self.buffer)


class LearningNode:
    """Main learning node for Q-learning with PyTorch"""

    def __init__(self, state_dim: int, action_dim: int, hidden_dim: int = 128, device: str = "cuda"):
        self.device = torch.device(device if torch.cuda.is_available() else "cpu")
        print(f"LearningNode: Using device {self.device}", file=sys.stderr)

        # Q-network and target network
        self.policy_net = QNetwork(state_dim, action_dim, hidden_dim).to(self.device)
        self.target_net = QNetwork(state_dim, action_dim, hidden_dim).to(self.device)
        self.target_net.load_state_dict(self.policy_net.state_dict())
        self.target_net.eval()

        # Optimizer
        self.optimizer = optim.Adam(self.policy_net.parameters(), lr=0.001)

        # Training state
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.gamma = 0.99
        self.epsilon = 1.0
        self.epsilon_min = 0.01
        self.epsilon_decay = 0.995
        self.batch_size = 64
        self.replay_buffer = ReplayBuffer(capacity=10000)
        self.total_steps = 0
        self.episode_count = 0

    def get_action(self, observations: List[float]) -> int:
        """Epsilon-greedy action selection"""
        if random.random() < self.epsilon:
            return random.randint(0, self.action_dim - 1)

        with torch.no_grad():
            state = torch.FloatTensor(observations).unsqueeze(0).to(self.device)
            q_values = self.policy_net(state)
            return q_values.argmax().item()

    def train_step(self, observations: List[List[float]], actions: List[int],
                   rewards: List[float], gamma: float = 0.99) -> dict:
        """Process a batch of experience and perform training step"""

        self.gamma = gamma

        # Add to replay buffer
        for i in range(len(observations)):
            self.replay_buffer.push(
                observations[i],
                actions[i],
                rewards[i],
                observations[i],  # Simplified - should be next state
                False
            )
            self.total_steps += 1

        # Only train if enough samples
        if len(self.replay_buffer) < self.batch_size:
            return {"status": "ok", "loss": 0.0}

        # Sample batch
        batch = self.replay_buffer.sample(self.batch_size)
        states, actions_batch, rewards_batch, _, _ = zip(*batch)

        # Convert to tensors
        states = torch.FloatTensor(states).to(self.device)
        actions = torch.LongTensor(actions_batch).unsqueeze(1).to(self.device)
        rewards = torch.FloatTensor(rewards_batch).to(self.device)

        # Compute Q values
        q_values = self.policy_net(states).gather(1, actions).squeeze()

        # Compute target
        with torch.no_grad():
            target_q = rewards  # Simplified - should use target network

        # Compute loss and update
        loss = F.mse_loss(q_values, target_q)
        self.optimizer.zero_grad()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(self.policy_net.parameters(), 1.0)
        self.optimizer.step()

        return {
            "status": "ok",
            "loss": loss.item(),
            "done": False
        }

    def save_model(self, path: str) -> bool:
        """Save model checkpoint"""
        try:
            checkpoint = {
                "policy_net": self.policy_net.state_dict(),
                "target_net": self.target_net.state_dict(),
                "optimizer": self.optimizer.state_dict(),
                "epsilon": self.epsilon,
                "total_steps": self.total_steps,
                "episode_count": self.episode_count
            }
            torch.save(checkpoint, path)
            return True
        except Exception as e:
            print(f"Save error: {e}", file=sys.stderr)
            return False

    def load_model(self, path: str) -> bool:
        """Load model checkpoint"""
        try:
            checkpoint = torch.load(path, map_location=self.device)
            self.policy_net.load_state_dict(checkpoint["policy_net"])
            self.target_net.load_state_dict(checkpoint["target_net"])
            self.optimizer.load_state_dict(checkpoint["optimizer"])
            self.epsilon = checkpoint.get("epsilon", 0.01)
            self.total_steps = checkpoint.get("total_steps", 0)
            self.episode_count = checkpoint.get("episode_count", 0)
            return True
        except Exception as e:
            print(f"Load error: {e}", file=sys.stderr)
            return False

    def batch_raycast(self, origin: List[float], directions: List[List[float]],
                      max_distance: float = 30.0, noise_stddev: float = 0.0) -> List[float]:
        """GPU batch raycast for LIDAR simulation"""
        # This is a stub - actual raycasting happens in Godot
        # PyTorch can be used for noise application
        ranges = []
        for d in directions:
            dist = random.gauss(max_distance * 0.5, noise_stddev) if noise_stddev > 0 else max_distance * 0.5
            dist = max(0.1, min(max_distance, dist))
            ranges.append(dist)
        return ranges


class ActorCritic(nn.Module):
    """Actor-Critic network for PPO"""
    def __init__(self, state_dim: int, action_dim: int, hidden_dim: int = 128):
        super().__init__()
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

    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        action_logits = self.actor(x)
        value = self.critic(x)
        return action_logits, value


class PPONode:
    """PPO implementation for policy gradient RL"""
    def __init__(self, state_dim: int, action_dim: int, hidden_dim: int = 128, device: str = "cpu"):
        self.device = torch.device(device if torch.cuda.is_available() else "cpu")
        self.policy = ActorCritic(state_dim, action_dim, hidden_dim).to(self.device)
        self.old_policy = ActorCritic(state_dim, action_dim, hidden_dim).to(self.device)
        self.old_policy.load_state_dict(self.policy.state_dict())
        self.optimizer = optim.Adam(self.policy.parameters(), lr=0.0003)
        self.gamma = 0.99
        self.epsilon_clip = 0.2
        self.gae_lambda = 0.95
        self.update_epochs = 10

    def get_action(self, observations: List[float], deterministic: bool = False) -> Dict:
        with torch.no_grad():
            state = torch.FloatTensor(observations).unsqueeze(0).to(self.device)
            action_logits, value = self.policy(state)
            probs = torch.softmax(action_logits, dim=-1)
            if deterministic:
                action = probs.argmax().item()
            else:
                dist = torch.distributions.Categorical(probs)
                action = dist.sample().item()
            log_prob = torch.log(probs[0, action] + 1e-8).item()
        return {"action": action, "log_prob": log_prob, "value": value.item()}

    def train_step(self, cmd: Dict) -> Dict:
        observations = cmd.get("observations", [])
        actions = cmd.get("actions", [])
        rewards = cmd.get("rewards", [])
        old_log_probs = cmd.get("old_log_probs", [])
        values = cmd.get("values", [])
        dones = cmd.get("dones", [])
        gamma = cmd.get("gamma", 0.99)
        epsilon_clip = cmd.get("epsilon_clip", 0.2)
        gae_lambda = cmd.get("gae_lambda", 0.95)

        if not observations:
            return {"status": "ok", "loss": 0.0, "entropy": 0.0, "mean_reward": 0.0}

        states = torch.FloatTensor(observations).to(self.device)
        actions_t = torch.LongTensor(actions).to(self.device)
        old_log_probs_t = torch.FloatTensor(old_log_probs).to(self.device)
        rewards_t = torch.FloatTensor(rewards).to(self.device)
        dones_t = torch.FloatTensor(dones).to(self.device)

        action_logits, values_pred = self.policy(states)
        dist = torch.distributions.Categorical(torch.softmax(action_logits, dim=-1))
        new_log_probs = dist.log_prob(actions_t)
        entropy = dist.entropy().mean().item()

        ratio = torch.exp(new_log_probs - old_log_probs_t)
        advantages = rewards_t - values_pred.detach().mean()
        surr1 = ratio * advantages
        surr2 = torch.clamp(ratio, 1.0 - epsilon_clip, 1.0 + epsilon_clip) * advantages
        loss = -torch.min(surr1, surr2).mean() - 0.01 * entropy

        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        mean_reward = rewards_t.mean().item() if len(rewards) > 0 else 0.0
        return {"status": "ok", "loss": loss.item(), "entropy": entropy, "mean_reward": mean_reward}


class SACNode:
    """SAC implementation for off-policy policy gradient RL"""
    def __init__(self, state_dim: int, action_dim: int, hidden_dim: int = 128, device: str = "cpu"):
        self.device = torch.device(device if torch.cuda.is_available() else "cpu")
        self.action_dim = action_dim
        self.gamma = 0.99
        self.tau = 0.005
        self.alpha = 0.2
        self.auto_alpha = True

        # Actor network
        self.actor = nn.Sequential(
            nn.Linear(state_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, action_dim)
        ).to(self.device)

        # Twin Q networks
        self.q1 = nn.Sequential(
            nn.Linear(state_dim + action_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 1)
        ).to(self.device)
        self.q2 = nn.Sequential(
            nn.Linear(state_dim + action_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 1)
        ).to(self.device)

        self.target_q1 = nn.Sequential(
            nn.Linear(state_dim + action_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 1)
        ).to(self.device)
        self.target_q2 = nn.Sequential(
            nn.Linear(state_dim + action_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 1)
        ).to(self.device)
        self.target_q1.load_state_dict(self.q1.state_dict())
        self.target_q2.load_state_dict(self.q2.state_dict())

        self.actor_opt = optim.Adam(self.actor.parameters(), lr=0.0003)
        self.q_opt = optim.Adam(list(self.q1.parameters()) + list(self.q2.parameters()), lr=0.0003)
        self.log_alpha = torch.tensor([math.log(0.2)], requires_grad=True, device=self.device)
        self.alpha_opt = optim.Adam([self.log_alpha], lr=0.0003)

    def get_action(self, observations: List[float], deterministic: bool = False) -> Dict:
        with torch.no_grad():
            state = torch.FloatTensor(observations).unsqueeze(0).to(self.device)
            action_logits = self.actor(state)
            probs = torch.softmax(action_logits, dim=-1)
            if deterministic:
                action = probs.argmax().item()
            else:
                dist = torch.distributions.Categorical(probs)
                action = dist.sample().item()
            log_prob = torch.log(probs[0, action] + 1e-8).item()
        return {"action": action, "log_prob": log_prob}

    def train_step(self, cmd: Dict) -> Dict:
        observations = cmd.get("observations", [])
        actions = cmd.get("actions", [])
        rewards = cmd.get("rewards", [])
        next_observations = cmd.get("next_observations", [])
        dones = cmd.get("dones", [])
        gamma = cmd.get("gamma", 0.99)
        tau = cmd.get("tau", 0.005)

        if not observations:
            return {"status": "ok", "loss": 0.0, "entropy": 0.0, "mean_reward": 0.0}

        states = torch.FloatTensor(observations).to(self.device)
        actions_t = torch.LongTensor(actions).to(self.device)
        rewards_t = torch.FloatTensor(rewards).to(self.device)
        next_states = torch.FloatTensor(next_observations).to(self.device)
        dones_t = torch.FloatTensor(dones).to(self.device)

        # Update Q networks
        with torch.no_grad():
            next_action_logits = self.actor(next_states)
            next_probs = torch.softmax(next_action_logits, dim=-1)
            next_log_probs = torch.log(next_probs + 1e-8)
            next_q = torch.min(self.target_q1(torch.cat([next_states, next_probs], dim=1)),
                              self.target_q2(torch.cat([next_states, next_probs], dim=1)))
            target_q = rewards_t.unsqueeze(1) + gamma * (1 - dones_t.unsqueeze(1)) * next_q

        q1_values = self.q1(torch.cat([states, F.one_hot(actions_t, self.action_dim).float()], dim=1))
        q2_values = self.q2(torch.cat([states, F.one_hot(actions_t, self.action_dim).float()], dim=1))
        q1_loss = F.mse_loss(q1_values, target_q)
        q2_loss = F.mse_loss(q2_values, target_q)
        q_loss = q1_loss + q2_loss

        self.q_opt.zero_grad()
        q_loss.backward()
        self.q_opt.step()

        # Update actor
        action_logits = self.actor(states)
        probs = torch.softmax(action_logits, dim=-1)
        log_probs = torch.log(probs + 1e-8)
        q_values = torch.min(self.q1(torch.cat([states, probs], dim=1)),
                            self.q2(torch.cat([states, probs], dim=1)))
        actor_loss = -(q_values.mean() + self.alpha * log_probs.mean())

        self.actor_opt.zero_grad()
        actor_loss.backward()
        self.actor_opt.step()

        entropy = probs.mean().item()
        mean_reward = rewards_t.mean().item() if len(rewards) > 0 else 0.0
        return {"status": "ok", "loss": q_loss.item(), "entropy": entropy, "mean_reward": mean_reward}


# Module-level dispatch functions for Godot GDScript calls
def ppo_train_step(cmd: Dict) -> Dict:
    if 'ppo_node' not in ppo_train_step.__dict__:
        ppo_train_step.ppo_node = PPONode(
            cmd.get('state_dim', 24), cmd.get('action_dim', 4),
            cmd.get('hidden_dim', 128), cmd.get('device', 'cpu'))
    return ppo_train_step.ppo_node.train_step(cmd)


def ppo_get_action(cmd: Dict) -> Dict:
    if 'ppo_node' not in ppo_get_action.__dict__:
        ppo_get_action.ppo_node = PPONode(
            cmd.get('state_dim', 24), cmd.get('action_dim', 4),
            cmd.get('hidden_dim', 128), cmd.get('device', 'cpu'))
    return ppo_get_action.ppo_node.get_action(cmd.get('observations', []))


def sac_train_step(cmd: Dict) -> Dict:
    if 'sac_node' not in sac_train_step.__dict__:
        sac_train_step.sac_node = SACNode(
            cmd.get('state_dim', 24), cmd.get('action_dim', 4),
            cmd.get('hidden_dim', 128), cmd.get('device', 'cpu'))
    return sac_train_step.sac_node.train_step(cmd)


def sac_get_action(cmd: Dict) -> Dict:
    if 'sac_node' not in sac_get_action.__dict__:
        sac_node = SACNode(
            cmd.get('state_dim', 24), cmd.get('action_dim', 4),
            cmd.get('hidden_dim', 128), cmd.get('device', 'cpu'))
        sac_get_action.sac_node = sac_node
    return sac_get_action.sac_node.get_action(cmd.get('observations', []))


def process_cmd(cmd, node, stdout_fn):
    """Process a single command. Returns updated node."""
    action = cmd.get("cmd", "")
    response = None

    if action == "init":
        state_dim = cmd.get("state_dim", 24)
        action_dim = cmd.get("action_dim", 4)
        hidden_dim = cmd.get("hidden_dim", 128)
        device = cmd.get("device", "cuda")
        node = LearningNode(state_dim, action_dim, hidden_dim, device)
        response = {"status": "ok", "cmd": "init", "device": str(node.device)}
    elif action == "train_step" and node:
        response = node.train_step(
            cmd.get("observations", []), cmd.get("actions", []),
            cmd.get("rewards", []), cmd.get("gamma", 0.99))
    elif action == "get_action" and node:
        act = node.get_action(cmd.get("observations", []))
        response = {"status": "ok", "action": act}
    elif action == "save_model" and node:
        success = node.save_model(cmd.get("path", "model.pt"))
        response = {"status": "ok" if success else "error"}
    elif action == "load_model" and node:
        success = node.load_model(cmd.get("path", "model.pt"))
        response = {"status": "ok" if success else "error"}
    elif action == "batch_raycast" and node:
        ranges = node.batch_raycast(
            cmd.get("origin", [0, 0, 0]), cmd.get("directions", []),
            cmd.get("max_distance", 30.0), cmd.get("noise_stddev", 0.0))
        response = {"status": "ok", "ranges": ranges}
    elif action == "ppo_train_step":
        response = ppo_train_step(cmd)
    elif action == "ppo_get_action":
        response = ppo_get_action(cmd)
    elif action == "sac_train_step":
        response = sac_train_step(cmd)
    elif action == "sac_get_action":
        response = sac_get_action(cmd)
    elif action == "shutdown":
        response = {"status": "ok", "cmd": "shutdown"}
    else:
        response = {"status": "error", "message": f"Unknown command: {action}"}

    if response:
        stdout_fn(json.dumps(response) + "\n")
    return node, response.get("cmd") == "shutdown" if response else False


def run_tcp_server(port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", port))
    server.listen(1)
    sys.stderr.write(f"PyTorch learning node listening on 127.0.0.1:{port}\n")
    sys.stderr.flush()
    conn, addr = server.accept()

    node = None
    buffer = ""
    while True:
        try:
            data = conn.recv(4096).decode("utf-8")
            if not data:
                break
            buffer += data
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    cmd = json.loads(line)
                except json.JSONDecodeError:
                    conn.sendall((json.dumps({"status": "error", "message": "Invalid JSON"}) + "\n").encode())
                    continue
                def send_fn(s):
                    conn.sendall(s.encode("utf-8"))
                node, shutdown = process_cmd(cmd, node, send_fn)
                if shutdown:
                    conn.close()
                    server.close()
                    return
        except (ConnectionResetError, BrokenPipeError):
            break
    conn.close()
    server.close()


def main():
    parser = argparse.ArgumentParser(description="PyTorch RL learning node")
    parser.add_argument("--tcp", action="store_true", help="Run in TCP server mode")
    parser.add_argument("--port", type=int, default=9877, help="TCP port (default: 9877)")
    args = parser.parse_args()

    if args.tcp:
        run_tcp_server(args.port)
    else:
        node = None
        try:
            for line in sys.stdin:
                line = line.strip()
                if not line:
                    continue
                try:
                    cmd = json.loads(line)
                except json.JSONDecodeError:
                    print(json.dumps({"status": "error", "message": "Invalid JSON"}))
                    continue
                def stdout_fn(s):
                    sys.stdout.write(s)
                    sys.stdout.flush()
                node, shutdown = process_cmd(cmd, node, stdout_fn)
                if shutdown:
                    break
        except KeyboardInterrupt:
            pass
        except EOFError:
            pass


if __name__ == "__main__":
    main()
