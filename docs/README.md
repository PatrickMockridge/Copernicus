# Robot Design POC — Documentation

## Overview

An AI-powered robot design tool built in Godot 4.3. The AI acts as a **code agent** — like Claude in VS Code — helping you write GDScript behaviors, debug issues, and architect robot systems.

---

## Contents

### [AI Code Agent](ai-code-agent.md)
What the AI does and how to use it. Covers behavior generation, debugging, topic explanation, and all available ROSAI methods.

### [Code Patterns](code-patterns.md)
Correct patterns for Godot 4.3 compatibility:
- **Signals + Thread** — replacing `async`/`await`
- **preload + new()** — accessing AI classes
- **Result.new()** — returning success/failure values
- **Signal-based callbacks** — async communication without coroutines

### [API Reference](api-reference.md)
Detailed API for ROSAIBehavior, GameAI, and Result type.

---

## Quick Start

```bash
# Run headless
godot4.3 --headless --quit

# Open in editor
godot4.3
```

In the Robot AI Assistant panel:
1. Enter your API key (Claude/OpenAI/Minimax)
2. Click "Connect AI"
3. Select a behavior type (obstacle_avoid, patrol, etc.)
4. Click "Generate Behavior"
5. Copy the generated code or view it in the output panel

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│  UI Layer (main.gd — Robot AI Assistant panel)   │
│  - API key input, behavior selector, task input  │
│  - Code output, action buttons                  │
├──────────────────────────────────────────────────┤
│  AI Code Agent (preload + new())               │
│  ├── GameAI — HTTP wrapper for AI providers      │
│  └── ROSAI — Robotics-specific generation       │
│      - generate_behavior(), diagnose_issue()    │
│      - explain_ros_topic(), generate_controller()│
├──────────────────────────────────────────────────┤
│  GodotROS2 (signals + thread)                  │
│  - ROS2Node, ROS2BridgeClient                 │
│  - connect_bridge() via thread                 │
│  - initialization_completed via signal          │
└──────────────────────────────────────────────────┘
```
