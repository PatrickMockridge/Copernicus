# Simulator Plugins

Plugin system for extending simulator functionality.

## Base Class (simulator_plugin.gd)

```gdscript
class_name SimulatorPlugin
```

### Methods

#### `get_name() -> String`
Returns the plugin name.

#### `is_enabled() -> bool`
Check if plugin is enabled.

#### `set_enabled(enabled: bool) -> void`
Enable or disable the plugin.

#### `on_load(simulator: ROS2Simulator) -> void`
Called when plugin is loaded. Override to access simulator.

#### `on_unload() -> void`
Called when plugin is unloaded.

#### `on_simulation_step(delta: float) -> void`
Called each simulation step.

#### `on_physics_step(delta: float) -> void`
Called each physics step.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `_simulator` | ROS2Simulator | Reference to parent simulator |

---

## PerformanceMonitor (performance_monitor.gd)

Monitor and log simulation performance metrics.

```gdscript
class_name PerformanceMonitor
extends SimulatorPlugin
```

### Methods

#### `get_average_fps() -> float`
Get average FPS over history.

#### `get_min_fps() -> float`
Get minimum FPS over history.

#### `get_max_fps() -> float`
Get maximum FPS over history.

#### `get_statistics() -> Dictionary`
Get all statistics:
```gdscript
{
    "average_fps": 60.0,
    "min_fps": 45.0,
    "max_fps": 72.0,
    "samples": 1000
}
```

---

## ContactVisualizer (contact_visualizer.gd)

Visualize physics contacts in the simulation.

```gdscript
class_name ContactVisualizer
extends SimulatorPlugin
```

### Methods

#### `on_physics_step(delta: float) -> void`
Called each physics step to update contact markers.

---

## TrajectoryRecorder (trajectory_recorder.gd)

Record robot trajectories over time.

```gdscript
class_name TrajectoryRecorder
extends SimulatorPlugin
```

### Methods

#### `start_recording(body_name: String) -> void`
Start recording a body's trajectory.

#### `stop_recording(body_name: String) -> Array`
Stop recording and return the trajectory array.

#### `record_pose(body_name: String, pose: Transform3D) -> void`
Manually record a pose.

#### `on_physics_step(delta: float) -> void`
Called each physics step to auto-record if recording.

---

## PhysicsLogger (physics_logger.gd)

Log physics data to a file.

```gdscript
class_name PhysicsLogger
extends SimulatorPlugin
```

### Methods

#### `set_log_path(path: String) -> void`
Set the log file path.

#### `add_body(body_name: String) -> void`
Add a body to log.

#### `on_load(simulator: ROS2Simulator) -> void`
Opens the log file for writing.

#### `on_physics_step(delta: float) -> void`
Called each physics step to write data.

#### `on_unload() -> void`
Closes the log file.

---

## Usage Example

```gdscript
extends Node3D

var sim: ROS2Simulator
var perf: PerformanceMonitor
var recorder: TrajectoryRecorder
var logger: PhysicsLogger

func _ready() -> void:
    sim = ROS2Simulator.new()
    add_child(sim)

    # Load performance monitor
    perf = PerformanceMonitor.new()
    sim.load_plugin(perf)

    # Load trajectory recorder
    recorder = TrajectoryRecorder.new()
    sim.load_plugin(recorder)
    recorder.start_recording("robot")

    # Load physics logger
    logger = PhysicsLogger.new()
    logger.set_log_path("user://physics_log.json")
    logger.add_body("robot")
    sim.load_plugin(logger)

func _physics_process(delta: float) -> void:
    # Check performance
    var stats = perf.get_statistics()
    print("FPS: ", stats["average_fps"])

func _exit_tree() -> void:
    # Stop recording
    var trajectory = recorder.stop_recording("robot")
    print("Recorded ", trajectory.size(), " poses")
```

## Source Files

| Class | File |
|-------|------|
| `SimulatorPlugin` | `core/simulator_plugin.gd` |
| `PerformanceMonitor` | `core/performance_monitor.gd` |
| `ContactVisualizer` | `core/contact_visualizer.gd` |
| `TrajectoryRecorder` | `core/trajectory_recorder.gd` |
| `PhysicsLogger` | `core/physics_logger.gd` |
