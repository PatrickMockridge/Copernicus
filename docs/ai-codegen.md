# AI Code Agent

Generate GDScript robot behaviors using AI (Claude via Minimax).

## Setup

### 1. Create `.env` file

Copy `.env.example` to `.env` and add your API key:

```bash
cp .env.example .env
```

Edit `.env`:
```
ANTHROPIC_API_KEY=your_minimax_api_key_here
ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic
```

The API key works with Claude Code in VS Code - use the same one here.

### 2. Run Godot

```bash
godot scenes/main.tscn
```

The AI panel connects automatically using the key from `.env`.

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

## Supported Providers

| Provider | Endpoint | Model |
|----------|----------|-------|
| Minimax (default) | `https://api.minimax.io/anthropic` | MiniMax-M2.7 |
| Anthropic (direct) | `https://api.anthropic.com/v1/messages` | claude-3-5-sonnet |

## Files

- `addons/GameAI/core/ai.gd` — Main AI SDK
- `addons/GameAI/core/config.gd` — Provider config
- `addons/GameAI/core/http_client.gd` — HTTP client
- `addons/GameAI/core/result.gd` — Result type
- `addons/GameAI/integrations/ros/ros_ai.gd` — ROS behavior prompts
- `addons/primitives/env/env_service.gd` — .env loader
