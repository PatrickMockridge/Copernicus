# AI Code Agent

The AI in this project functions as a **code agent** — like the Claude plugin in VS Code, but for robotics in Godot. It helps you write GDScript behaviors, debug issues, and architect robot systems.

## How It Works

The AI reads and understands your robot's context — its sensors, actuators, and existing code — then generates GDScript for you. You describe what you want in natural language, and the AI produces working code.

```
┌─────────────────────────────────────────────┐
│  Robot AI Assistant                         │
│                                             │
│  Task: "Generate obstacle avoidance"  [Go]  │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ extends Node                         │   │
│  │ class_name ObstacleAvoid             │   │
│  │ ...                                  │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  [Copy Code]  [Add to Scene]                │
└─────────────────────────────────────────────┘
```

## AI Providers

- **Anthropic Claude** — Best for code generation (default)
- **OpenAI GPT-4** — Alternative code generation
- **Minimax** — Budget-friendly option

## ROSAI Methods

All AI operations are asynchronous via signals. Connect to the signal that matches your operation.

### generate_behavior(behavior_type: String, params: Dictionary = {})

Generates GDScript for robot behaviors.

**Signal**: `behavior_generated(result: Result)`

**behavior_type** options:
- `obstacle_avoid` — LIDAR-based collision avoidance
- `wall_follow` — Maintain distance from walls
- `line_follow` — Follow a line on the ground
- `patrol` — Navigate between waypoints
- `chase` — Follow a moving target
- `flee` — Escape from threats

**params** can include:
- `robot_context` — Description of the robot's sensors/actuators
- `environment` — Description of the environment
- `extrarequirements` — Any specific requirements

**Example**:
```gdscript
_rosai.generate_behavior("obstacle_avoid", {
    "robot_context": "TurtleBot4 with RPLidar A1, differential drive",
    "environment": "Indoor office with obstacles"
})
```

---

### generate_sensor_processor(sensor_type: String, params: Dictionary = {})

Generates GDScript for processing sensor data.

**Signal**: `sensor_processor_generated(result: Result)`

**sensor_type** options:
- `lidar` — LaserScan processing (filtering, clustering, edge detection)
- `camera` — Image processing (color filtering, feature detection)
- `imu` — IMU data processing (complementary filter, sensor fusion)
- `odom` — Odometry processing (dead reckoning, wheel encoding)
- `ultrasonic` —超声波 sensor processing

---

### generate_controller(controller_type: String, params: Dictionary = {})

Generates control logic for robot movement.

**Signal**: `controller_generated(result: Result)`

**controller_type** options:
- `pid` — PID velocity/distance controller
- `pure_pursuit` — Path following controller
- `Stanley` — Autonomous vehicle controller
- `lqr` — Linear quadratic regulator
- `mpc` — Model predictive controller (simplified)

---

### explain_ros_topic(topic: String, msg_type: String)

Explains a ROS 2 topic, its message type, and how to use it.

**Signal**: `topic_explained(result: Result)`

```gdscript
_rosai.explain_ros_topic("/turtlebot4/scan", "sensor_msgs/LaserScan")
```

---

### diagnose_behavior_issue(symptoms: Array)

Debugs robot behavior problems.

**Signal**: `diagnosis_completed(result: Result)`

```gdscript
var symptoms = ["robot drifts left when moving forward", "odometry jumps"]
_rosai.diagnose_behavior_issue(symptoms)
```

---

### generate_state_machine(states: Array, params: Dictionary = {})

Generates a state machine for complex robot behaviors.

**Signal**: `state_machine_generated(result: Result)`

```gdscript
_rosai.generate_state_machine(["idle", "exploring", "avoiding", "returning"])
```

---

### generate_vision_pipeline(pipeline_type: String, params: Dictionary = {})

Generates vision processing pipelines.

**Signal**: `vision_pipeline_generated(result: Result)`

**pipeline_type** options:
- `object_detection` — Detect objects in camera images
- `line_detection` — Find lines/paths for line following
- `face_detection` — Detect faces
- `aruco` — ArUco marker detection for localization

---

### generate_waypoint_controller(waypoints: Array, params: Dictionary = {})

Generates waypoint navigation controller.

**Signal**: `waypoint_controller_generated(result: Result)`

---

### generate_multi_robot_logic(robot_count: int, params: Dictionary = {})

Generates coordination logic for multiple robots.

**Signal**: `multi_robot_logic_generated(result: Result)`

---

### generate_robot_brain(config: Dictionary)

Generates a complete robot "brain" — integration of all behaviors, perception, and decision making.

**Signal**: `robot_brain_generated(result: Result)**

---

## Signal Response Handling

All ROSAI methods return results via signals. Handle them like this:

```gdscript
func _ready() -> void:
    _rosai.behavior_generated.connect(_on_behavior_generated)

func _on_behavior_generated(result: Result) -> void:
    if result.is_ok():
        var content = result.ok_value()
        if content is Dictionary:
            content = content.get("content", str(content))
        _code_output.text = str(content)
    else:
        var err = result.err_value()
        _code_output.text = "Error: " + str(err)
```

## AI Context

The AI understands your robot's context automatically when you provide it in `params`. For better results, include:

- **robot_context** — Sensor and actuator configuration
- **environment** — Where the robot operates
- **existing_code** — Any current GDScript the robot uses

## Usage Example

```gdscript
func _on_generate_pressed() -> void:
    var behavior = _behavior_select.get_item_text(_behavior_select.selected)
    _rosai.generate_behavior(behavior, {
        "robot_context": "TurtleBot4 with RPLidar A1, Create3 base",
        "environment": "Indoor office with people"
    })

func _on_behavior_generated(result: Result) -> void:
    if result.is_ok():
        var code = result.ok_value().get("content", "")
        _code_output.text = code
        _add_to_scene_btn.disabled = false
```

The AI generates clean, documented GDScript compatible with Godot 4.3 and the GodotROS2 SDK.