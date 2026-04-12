#!/usr/bin/env python3
# pytorch_learning_node.py
# PyTorch Q-learning subprocess for Copernicus GPU learning
# Provides DQN reinforcement learning with CUDA support

import sys
import json
import random
import math
from dataclasses import dataclass
from typing import List, Tuple, Optional

try:
    import torch
    import torch.nn as nn
    import torch.optim as optim
    import torch.nn.functional as F
except ImportError:
    print(json.dumps({"status": "error", "message": "PyTorch not available"}))
    sys.exit(1)


@dataclass
class QNetwork(nn.Module):
    """Deep Q-Network for reinforcement learning"""
    state_dim: int
    action_dim: int
    hidden_dim: int = 128

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


def main():
    """Main loop - process commands from stdin"""
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

            action = cmd.get("cmd", "")

            if action == "init":
                state_dim = cmd.get("state_dim", 24)
                action_dim = cmd.get("action_dim", 4)
                hidden_dim = cmd.get("hidden_dim", 128)
                device = cmd.get("device", "cuda")
                node = LearningNode(state_dim, action_dim, hidden_dim, device)
                print(json.dumps({"status": "ok", "cmd": "init",
                                 "device": str(node.device)}))

            elif action == "train_step" and node:
                result = node.train_step(
                    cmd.get("observations", []),
                    cmd.get("actions", []),
                    cmd.get("rewards", []),
                    cmd.get("gamma", 0.99)
                )
                print(json.dumps(result))

            elif action == "get_action" and node:
                action = node.get_action(cmd.get("observations", []))
                print(json.dumps({"status": "ok", "action": action}))

            elif action == "save_model" and node:
                success = node.save_model(cmd.get("path", "model.pt"))
                print(json.dumps({"status": "ok" if success else "error"}))

            elif action == "load_model" and node:
                success = node.load_model(cmd.get("path", "model.pt"))
                print(json.dumps({"status": "ok" if success else "error"}))

            elif action == "batch_raycast" and node:
                ranges = node.batch_raycast(
                    cmd.get("origin", [0, 0, 0]),
                    cmd.get("directions", []),
                    cmd.get("max_distance", 30.0),
                    cmd.get("noise_stddev", 0.0)
                )
                print(json.dumps({"status": "ok", "ranges": ranges}))

            elif action == "shutdown":
                print(json.dumps({"status": "ok", "cmd": "shutdown"}))
                break

            else:
                print(json.dumps({"status": "error", "message": f"Unknown command: {action}"}))

    except KeyboardInterrupt:
        pass
    except EOFError:
        pass


if __name__ == "__main__":
    main()
