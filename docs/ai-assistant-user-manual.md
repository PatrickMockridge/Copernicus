# Copernicus AI Assistant — User Manual

The AI assistant is a toggleable panel on the right of the window. It is an **agentic Claude
integration**: you give it a task, and Claude uses **tools** to read and edit files in a **user
workspace** directly — it codes for itself. You review the changes with your own editor/git.

## 1. Configure

The assistant reads its configuration from `.env` in the repository root:

```bash
cd /home/patrick/Godot/Godot_4_Robotic_Design_Interface   # your checkout
cp .env.example .env
# edit .env and set ANTHROPIC_API_KEY
godot scenes/main.tscn
```

| Variable | Required | Default | Meaning |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | yes | — | Your key for the Anthropic-compatible endpoint. |
| `ANTHROPIC_BASE_URL` | no | `https://api.anthropic.com` | Base URL of the `/v1/messages` endpoint. |
| `ANTHROPIC_MODEL` | no | `claude-sonnet-4-6` | Model id (must support tool use). |
| `AI_WORKSPACE` | no | `~/robot_workspace` | Directory the assistant codes in — **your** project, not Copernicus. |

On launch the panel **tests** the connection (a real round-trip to the endpoint, not just a key
presence check) and shows "Connected (model)" or a loud "Connection failed: …". If it can't connect,
enter your key in the panel and press **Connect** — a successful manual key is saved to
`user://ai_config.json` so it survives relaunch.

## 2. Open / close

| Action | Control |
|---|---|
| Toggle the panel | the **AI** button in the top-right of the viewport, or **Tools → AI Assistant** |
| Toggle via terminal | `open ai` |
| Close | the **✕** button in the panel's top-right corner |

## 3. Using it

Type a task in the input box and press **Send**. Claude works step by step in your workspace: it
reads the relevant files, then edits or writes them. The chat shows the conversation and each tool
call.

Example:

```
> add an "obstacle_avoid" behavior script that turns the robot away from the nearest lidar hit
```

Claude reads your workspace's robot/lidar scripts, then writes
`~/robot_workspace/scripts/behaviors/obstacle_avoid.gd` (or wherever your `AI_WORKSPACE` points).

Review the result with your own editor or git — the panel doesn't add its own review buttons.

## 4. Tools

Claude can call these tools while coding:

| Tool | What it does |
|---|---|
| `read_file` | Read a workspace file. |
| `write_file` | Write (or overwrite) a file, creating parent directories. |
| `edit_file` | Replace one exact occurrence of a string (targeted edit). |
| `list_files` | List workspace files, optionally by extension. |
| `search` | Find files containing a substring. |

All paths are clamped to `AI_WORKSPACE` — Claude cannot write outside your workspace.

## 5. Providers

The assistant speaks the Anthropic Messages API, so any Anthropic-compatible endpoint that supports
tool use works:

| Provider | `ANTHROPIC_BASE_URL` | `ANTHROPIC_MODEL` (example) |
|---|---|---|
| Anthropic Claude (default) | *(leave unset)* | *(leave unset)* |
| Minimax (Anthropic-compatible) | `https://api.minimax.io/anthropic` | `MiniMax-M2.7` |
| Deepseek (Anthropic-compatible) | your provider's base URL | your provider's model id |
