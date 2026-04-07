# GameAI SDK

**AI integration for Godot 4** — Connect your game to Claude, OpenAI, Minimax, and other AI providers. Build smarter NPCs, generate code dynamically, create procedural content, and more.

## Features

- **Multi-Provider Support**: Anthropic Claude, OpenAI, Minimax, and custom providers
- **ROS Integration**: AI-assisted robotics development with GodotROS2
- **In-Game Coding**: Roblox-style code generation for game objects
- **Character AI**: Intelligent NPCs, companions, and game characters
- **NPC Dialogue System**: Stateful NPCs with personality and memory
- **Code Generation**: Generate GDScript, Python, JavaScript, and more
- **World Building**: Procedural quests, items, dungeons

## Quick Start

```gdscript
extends Node

func _ready():
    # Configure with your API key
    GameAI.configure({
        "anthropic": {"api_key": "sk-..."},
        "default": "anthropic"
    })

    # Chat with AI
    var result = await GameAI.chat([
        {"role": "user", "content": "Hello!"}
    ])
    print(result.ok_value().content)
```

## Providers

| Provider | Models | Streaming |
|----------|--------|-----------|
| Anthropic Claude | claude-3-5-sonnet, claude-3-opus | Yes |
| OpenAI | gpt-4o, gpt-4-turbo, gpt-3.5-turbo | Yes |
| Minimax | MiniMax-Text-01 | No |

## Integration Modules

### ROSAI - Robotics Development

AI-powered robotics development with GodotROS2 integration:

```gdscript
var ros_ai = ROSAI.new()
ros_ai.set_ai(GameAI)
ros_ai.set_godot_ros2("/path/to/ros2_ws")

# Generate obstacle avoidance behavior
var code = await ros_ai.generate_behavior("obstacle_avoid")

# Generate PID controller
var pid = await ros_ai.generate_controller("position")

# Diagnose robot issues
var diagnosis = await ros_ai.diagnose_behavior_issue(["robot drifts left", "lidar data noisy"])
```

### RobloxAI - In-Game Code Generation

Roblox-style code generation for game development:

```gdscript
var rb_ai = RobloxAI.new()
rb_ai.set_ai(GameAI)

# Generate NPC behavior
var npc_code = await rb_ai.generate_npc_script("guard", "Gruff but honorable")

# Generate weapon script
var sword_code = await rb_ai.generate_tool_script("Flame Sword", "sword")

# Generate game mechanic
var grapple = await rb_ai.generate_mechanic("grapple_hook", "Swing between anchor points")
```

### CharacterAI - Game Characters

AI-powered NPCs and companions:

```gdscript
var char_ai = CharacterAI.new()
char_ai.set_ai(GameAI)

# Create companion
char_ai.create_companion("wise_dragon", "Pyrhon", "Ancient and wise", ["history", "magic", "puzzles"])

# Talk to character
var response = await char_ai.talk_to("wise_dragon", "Hello, wise one. What do you know of the ancient kingdom?")

# Create enemy
char_ai.create_enemy("boss", "Malachar", "Cunning and ruthless", "hard")

# Combat dialogue
var taunt = await char_ai.combat_dialogue("boss", "You dare enter my domain?")
```

## Character Types

```gdscript
# Companion - Helpful ally with expertise
char_ai.create_companion(id, name, personality, expertise_array)

# Enemy - Combat opponent
char_ai.create_enemy(id, name, personality, difficulty)

# Merchant - Buy/sell with dialogue
char_ai.create_merchant(id, name, inventory, specialties)

# Guard - Faction-based NPC
char_ai.create_guard(id, faction, personality)
```

## NPC Dialogue System

```gdscript
# Initialize an NPC with personality
GameAI.npc_init("guard", "A gruff dwarven guard who loves ale")
GameAI.npc_say("guard", "What brings you here, stranger?")

# Later, get response
var response = await GameAI.npc_say("guard", "I seek passage through the gate")
```

## Code Generation

```gdscript
# Generate code in any language
var code = await GameAI.generate_code(
    "a platformer jump mechanic with coyote time",
    "gdscript"
)

# Explain code
var explanation = await GameAI.explain_code(code)

# Debug an error
var fix = await GameAI.debug_script(broken_code, "error: unexpected token")
```

## World Building

```gdscript
# Generate quests
var quest = await GameAI.generate_quest("rescue a princess", "hard")

# Generate item names
var item = await GameAI.generate_item_name("sword", "legendary")

# Generate dungeon layouts
var dungeon = await GameAI.generate_dungeon_layout("large", "haunted")
```

## SDK Components

| Module | Purpose |
|--------|---------|
| `core/ai.gd` | Main entry point (autoload: GameAI) |
| `core/config.gd` | Provider API key management |
| `core/http_client.gd` | HTTP requests to AI providers |
| `core/result.gd` | Result type for async operations |
| `integrations/ros/ros_ai.gd` | GodotROS2 behavior generation |
| `integrations/roblox/roblox_ai.gd` | In-game code generation |
| `integrations/characters/character_ai.gd` | NPC/companion AI |

## API Reference

### Configuration

```gdscript
GameAI.configure({
    "anthropic": {"api_key": "sk-ant-..."},
    "openai": {"api_key": "sk-..."},
    "minimax": {"api_key": "..."},
    "default": "anthropic"
})
```

### Chat

```gdscript
# Basic chat
var result = await GameAI.chat(messages)

# With system prompt
var result = await GameAI.chat_system(
    "You are a helpful assistant",
    "What's the weather?"
)

# Provider-specific params
var result = await GameAI.chat(messages, {
    "provider": "openai",
    "model": "gpt-4o",
    "temperature": 0.7
})
```

### Messages Format

```gdscript
var messages = [
    {"role": "system", "content": "You are a game master"},
    {"role": "user", "content": "Create a quest for me"},
    {"role": "assistant", "content": "Here's your quest..."},
    {"role": "user", "content": "Make it harder"}
]
```

## License

MIT
