# AI Code Agent

Generate GDScript robot behaviors using AI (Anthropic-compatible API — Claude by default).

See [the AI assistant user manual](../ai-assistant-user-manual.md) for the panel, setup, and
configuration.

## Setup

### 1. Create `.env` file

From the repository root, copy `.env.example` to `.env` and add your key:

```bash
cd /home/patrick/Godot/Godot_4_Robotic_Design_Interface
cp .env.example .env
```

Edit `.env`:
```
ANTHROPIC_API_KEY=sk-ant-...
```

Optionally set `ANTHROPIC_BASE_URL` and `ANTHROPIC_MODEL` to point at any Anthropic-compatible
endpoint (Deepseek, Minimax, …). Defaults are `https://api.anthropic.com` and `claude-sonnet-4-6`.

### 2. Run Godot

```bash
godot scenes/main.tscn
```

The AI panel connects automatically on launch using the key from `.env`.

## Usage

### Connect AI

Click "Connect AI" or leave blank to use `.env` key automatically.

### Generate Behavior

1. Select behavior type (obstacle_avoid, wall_follow, patrol, etc.)
2. Click "Generate Behavior"
3. Copy generated code or add to scene

### Other Commands

- **Explain Topic** — Ask about ROS/robot concepts
- **Debug Issue** — Describe a problem, get diagnosis

## Architecture

```
GameAI (autoload)
├── ai.gd — Chat/behavior generation
├── config.gd — API key management
├── http_client.gd — curl-based HTTP
└── EnvService — Loads .env file

ROSAI (autoload)
└── ros_ai.gd — ROS-specific behavior prompts
```

## ROS Coder IDE

The ROS Coder is a minimalist in-game IDE for writing and deploying ROS2 Python (rclpy) robot software. It generates code via AI and can deploy directly to a robot.

Open via the **ROS Coder** button in the main AI panel header.

### Generating Python Code

1. Open ROS Coder from the main AI panel
2. Select a preset (Obstacle Avoidance, Wall Following, Patrol, etc.) or enter a custom prompt
3. Click **Generate** — rclpy Python code appears in the editor with syntax highlighting
4. Edit the code as needed
5. Click **Run** to test locally, **Save** to save to workspace, or **Deploy** to push to the robot
6. Click **Launch** to generate a Python-based ROS2 launch file for the node

### Preset Prompts

The ROS Coder includes preset prompts for common robot behaviors:
- **Obstacle Avoidance** — Navigate around obstacles using laser scan
- **Wall Following** — Follow a wall at a set distance
- **Line Following** — Follow a line on the ground using camera/sensors
- **Patrol** — Navigate between multiple waypoints
- **Person Following** — Detect and follow a person
- **Navigation** — Nav2 autonomous navigation using NavigateToPose action client, costmap navigation, and obstacle avoidance

### Architecture

```
ROSCoder (addons/ROSCoder/)
├── ros_coder.gd              — Main controller, split panel layout
├── ui/
│   ├── code_editor.gd       — CodeEdit with Python syntax highlighting
│   ├── python_syntax_highlighter.gd — Custom highlighter (optional, CodeEdit has built-in)
│   ├── file_tree.gd          — Tree browser for ~/.ros_workspace/
│   ├── ai_prompt_bar.gd      — Preset selector + Generate/Run/Save/Launch/Deploy
│   └── console_output.gd    — Terminal-style output display
└── coders/
    └── python_coder.gd       — AI prompts + launch file generation + multi-file package
```

### Workspace

The file browser shows `~/.ros_workspace/`. Set up with:

```bash
mkdir -p ~/.ros_workspace/{src,config}
```

For SSH deploy, create `~/.ros_workspace/config/robot_config.json`:

```json
{
  "host": "192.168.1.100",
  "port": 22,
  "username": "robot",
  "remote_path": "/home/robot/catkin_ws/src/"
}
```

## Supported Providers

The assistant speaks the Anthropic Messages API (`/v1/messages`), so any Anthropic-compatible endpoint
works — set `ANTHROPIC_BASE_URL` + `ANTHROPIC_MODEL` in `.env`.

| Provider | `ANTHROPIC_BASE_URL` | Model (example) |
|----------|----------------------|-----------------|
| Anthropic Claude (default) | *(unset — `https://api.anthropic.com`)* | `claude-sonnet-4-6` |
| Minimax (Anthropic-compatible) | `https://api.minimax.io/anthropic` | `MiniMax-M2.7` |
| Deepseek (Anthropic-compatible) | provider's base URL | provider's model id |

## Files

- `addons/GameAI/core/ai.gd` — Main AI SDK
- `addons/GameAI/core/config.gd` — Provider config
- `addons/GameAI/core/http_client.gd` — HTTP client
- `addons/GameAI/core/result.gd` — Result type
- `addons/GameAI/integrations/ros/ros_ai.gd` — ROS behavior prompts
- `addons/primitives/env/env_service.gd` — .env loader
- `addons/ROSCoder/ros_coder.gd` — ROS Coder main controller
- `addons/ROSCoder/coders/python_coder.gd` — rclpy AI code generation
