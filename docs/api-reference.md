# API Reference

## Result

Result type for success/failure values. No static constructors — use `Result.new()` directly.

### Class Definition

```gdscript
class_name Result
```

### Methods

#### is_ok() -> bool
Returns true if the result is a success.

#### is_err() -> bool
Returns true if the result is a failure.

#### ok_value() -> Variant
Returns the success value. Undefined if is_err() is true.

#### err_value() -> Dictionary
Returns the error dictionary with `code` (int) and `message` (String).

#### get_or_default(default_value: Variant) -> Variant
Returns ok_value if is_ok(), otherwise returns the default.

### Construction

```gdscript
# Success
Result.new(true, value)
Result.new(true, {"content": "text", "provider": "anthropic"})

# Failure
Result.new(false, null, {"code": -1, "message": "Error text"})
```

---

## GameAI (ai.gd)

AI provider wrapper — supports Anthropic Claude, OpenAI, and Minimax.

### Initialization

```gdscript
const GameAI = preload("res://addons/GameAI/core/ai.gd")
var _gameai = GameAI.new()
add_child(_gameai)
```

### Configuration

```gdscript
# With API key
_gameai.configure({
    "anthropic": {"api_key": "sk-ant-..."},
    "default": "anthropic"
})

# Or for OpenAI
_gameai.configure({
    "openai": {"api_key": "sk-..."},
    "default": "openai"
})
```

### Configuration Schema

| Field | Type | Description |
|-------|------|-------------|
| `anthropic.api_key` | String | Anthropic API key |
| `openai.api_key` | String | OpenAI API key |
| `minimax.api_key` | String | Minimax API key |
| `default` | String | Default provider name |

### Methods

#### configure(config: Dictionary) -> void
Configure AI providers with API keys.

#### get_config() -> AIConfig
Returns the current configuration object.

#### set_default_provider(provider: String) -> void
Set the default provider ("anthropic", "openai", "minimax").

#### get_default_provider() -> String
Returns the current default provider.

#### chat(messages: Array, params: Dictionary = {}) -> Result
Send chat messages to the AI.
- `messages`: `[{"role": "user", "content": "..."}]`
- `params`: Optional `{"provider": "anthropic", "max_tokens": 1024}`

#### chat_system(system: String, user_message: String, params: Dictionary = {}) -> Result
Convenience method for single chat with system prompt.

#### generate_code(task: String, language: String = "gdscript") -> Result
Generate code for a task. Returns Result with `content` field.

#### explain_code(code: String) -> Result
Explain what code does.

### Signals

#### chat_stream_chunk(chunk: String, provider: String)
Emitted during streaming chat for each chunk.

---

## ROSAI (ros_ai.gd)

Robotics-specific AI code agent built on GameAI. Generates GDScript for robot behaviors, controllers, state machines; debugs issues; explains ROS topics.

### Initialization

```gdscript
const ROSAI = preload("res://addons/GameAI/integrations/ros/ros_ai.gd")
var _rosai = ROSAI.new()
add_child(_rosai)
_rosai.set_ai(_gameai)  # Connect to GameAI instance
```

### Configuration

```gdscript
# Set API key on the underlying GameAI
_gameai.configure({"anthropic": {"api_key": "sk-ant-..."}, "default": "anthropic"})
```

### Methods

All methods are async — they return via signals, not direct return values.

#### set_ai(ai: Node) -> void
Connect to a GameAI instance.

#### generate_behavior(behavior_type: String, params: Dictionary = {}) -> void
Generate robot behavior GDScript.

**Signal**: `behavior_generated(result: Result)`

**behavior_type**: `obstacle_avoid`, `wall_follow`, `line_follow`, `patrol`, `chase`, `flee`

**params**: Optional `robot_context`, `environment`, `extrarequirements`

#### generate_sensor_processor(sensor_type: String, params: Dictionary = {}) -> void
Generate sensor processing GDScript.

**Signal**: `sensor_processor_generated(result: Result)`

**sensor_type**: `lidar`, `camera`, `imu`, `odom`, `ultrasonic`

#### generate_controller(controller_type: String, params: Dictionary = {}) -> void
Generate control logic GDScript.

**Signal**: `controller_generated(result: Result)`

**controller_type**: `pid`, `pure_pursuit`, `Stanley`, `lqr`, `mpc`

#### explain_ros_topic(topic: String, msg_type: String) -> void
Explain a ROS topic.

**Signal**: `topic_explained(result: Result)`

#### diagnose_behavior_issue(symptoms: Array) -> void
Debug robot behavior problems.

**Signal**: `diagnosis_completed(result: Result)`

**symptoms**: Array of strings describing the problem

#### generate_state_machine(states: Array, params: Dictionary = {}) -> void
Generate state machine GDScript.

**Signal**: `state_machine_generated(result: Result)`

#### generate_vision_pipeline(pipeline_type: String, params: Dictionary = {}) -> void
Generate vision processing GDScript.

**Signal**: `vision_pipeline_generated(result: Result)`

**pipeline_type**: `object_detection`, `line_detection`, `face_detection`, `aruco`

#### generate_waypoint_controller(waypoints: Array, params: Dictionary = {}) -> void
Generate waypoint navigation GDScript.

**Signal**: `waypoint_controller_generated(result: Result)`

#### generate_multi_robot_logic(robot_count: int, params: Dictionary = {}) -> void
Generate multi-robot coordination GDScript.

**Signal**: `multi_robot_logic_generated(result: Result)`

#### generate_robot_brain(config: Dictionary) -> void
Generate complete robot brain GDScript.

**Signal**: `robot_brain_generated(result: Result)`

### Signals Summary

| Signal | Payload | Description |
|--------|---------|-------------|
| `behavior_generated` | Result | Behavior code ready |
| `sensor_processor_generated` | Result | Sensor processing code ready |
| `controller_generated` | Result | Controller code ready |
| `topic_explained` | Result | Topic explanation ready |
| `diagnosis_completed` | Result | Diagnosis ready |
| `state_machine_generated` | Result | State machine code ready |
| `vision_pipeline_generated` | Result | Vision pipeline code ready |
| `waypoint_controller_generated` | Result | Waypoint controller ready |
| `multi_robot_logic_generated` | Result | Multi-robot logic ready |
| `robot_brain_generated` | Result | Robot brain code ready |

---

## GodotROS2 (godot_ros2.gd)

Main entry point for ROS 2 integration.

### Initialization

```gdscript
const GodotROS2 = preload("res://addons/godot_ros2/godot_ros2.gd")
var _ros2 = GodotROS2.new()
add_child(_ros2)
```

### Methods

#### initialize(node_name: String, ns: String = "", bridge_host: String = "127.0.0.1") -> void
Initialize the ROS 2 node. Starts the bridge connection.

**Signal**: `initialization_completed(success: bool)`

#### connect_bridge() -> void
Connect to the godot_ros2_bridge node.

**Signal**: `bridge_connection_completed(success: bool)`

---

## HttpClient (http_client.gd)

HTTP client for AI provider API calls.

### Initialization

```gdscript
const HttpClient = preload("res://addons/GameAI/core/http_client.gd")
var _http = HttpClient.new()
add_child(_http)
```

### Methods

#### set_timeout(seconds: float) -> void
Set request timeout (default 30 seconds).

#### post(url: String, headers: Array, body: String) -> Result
Send POST request. Returns response body as string in Result.

#### post_stream(url: String, headers: Array, body: String) -> Result
Send streaming POST request (for SSE responses).

---

## ROS2BridgeClient (ros2_bridge_client.gd)

Client for TCP/UDP bridge to godot_ros2_bridge node.

### Methods

#### connect_bridge() -> void
Connect to the bridge node (TCP port 8765, UDP port 8766).

**Signal**: `bridge_connection_completed(success: bool)`