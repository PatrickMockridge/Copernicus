# Robot Design POC

**Proof of Concept: AI-powered robot design with GameAI + GodotROS2**

A demonstration of integrating AI code generation with robotics simulation in Godot 4.

## Concept

This POC shows how AI can assist in robot design by:
1. Letting users configure robot type and desired behavior
2. Using GameAI to generate GDScript code for the behavior
3. The generated code integrates with GodotROS2 SDK

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Robot Design POC                          │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Godot Controls)                                  │
│  ├── Robot Type Selector                                    │
│  ├── Sensors Input                                         │
│  ├── Behavior Selector                                     │
│  └── Generated Code Display                                │
├─────────────────────────────────────────────────────────────┤
│  GameAI SDK                                                 │
│  ├── AI Provider Integration (Claude, OpenAI, etc.)       │
│  └── ROSAI Module                                          │
│      └── Behavior Generation                                │
├─────────────────────────────────────────────────────────────┤
│  GodotROS2 SDK                                             │
│  └── Robotics Simulation                                   │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

- Godot 4.2+
- GameAI SDK addon
- GodotROS2 SDK addon
- Anthropic API key (or OpenAI/Minimax)

## Setup

1. Open project in Godot 4.2+
2. Enable both addons in Project Settings > Plugins
3. Run the project
4. Enter your Anthropic API key
5. Configure robot type and desired behavior
6. Click "Generate Robot Behavior with AI"

## Features Demonstrated

- **Multi-provider AI**: Connects to Claude, OpenAI, or Minimax
- **Behavior Generation**: AI generates GDScript for obstacle avoidance, wall following, patrol, etc.
- **Sensor Integration**: Supports lidar, camera, IMU, GPS configurations
- **GodotROS2 Compatible**: Generated code works with GodotROS2 SDK

## Usage Flow

1. **Connect**: Enter API key to connect to AI provider
2. **Configure**: Select robot type and sensors
3. **Generate**: AI produces GDScript behavior code
4. **Apply**: Use generated code in your GodotROS2 project

## Example Generated Behaviors

- `obstacle_avoid`: Lidar-based collision avoidance
- `wall_follow`: Maintain distance from walls
- `patrol`: Navigate between waypoints
- `chase`: Follow a moving target
- `flee`: Escape from threats

## License

MIT
