# ros_ai.gd
# ROSAIBehavior - AI Code Agent for Robotics in Godot
# Like Claude in VS Code, but for robot design — embedded AI that helps you
# write, debug, and architect GDScript for your GodotROS2 robots

extends Node
class_name ROSAIBehavior

const GameAIResult = preload("res://addons/GameAI/core/result.gd")

## ROSAIBehavior - AI Coding Assistant for GodotROS2
##
## Acts as an AI code agent for robotics in Godot. Generate behaviors,
## debug issues, explain sensor math, and architect control systems.
## Works WITH GodotROS2 SDK (doesn't replace it).
##
## Example usage:
##   ros_ai.set_ai(GameAI)
##   ros_ai.generate_behavior("obstacle_avoid")   # returns code via signal
##   ros_ai.diagnose_behavior_issue(["robot drifts left", "odometry noisy"])
##   ros_ai.explain_ros_topic("/turtlebot4/scan", "sensor_msgs/LaserScan")
##
## All methods emit signals with generated code/text. Connect to the
## appropriate signal to receive results asynchronously.

var _ros2_path: String = ""
var _ai: Node = null

signal behavior_generated(result: GameAIResult)
signal sensor_processor_generated(result: GameAIResult)
signal controller_generated(result: GameAIResult)
signal topic_explained(result: GameAIResult)
signal diagnosis_completed(result: GameAIResult)
signal state_machine_generated(result: GameAIResult)
signal vision_pipeline_generated(result: GameAIResult)
signal waypoint_controller_generated(result: GameAIResult)
signal multi_robot_logic_generated(result: GameAIResult)
signal robot_brain_generated(result: GameAIResult)

func set_godot_ros2(workspace_path: String) -> void:
	_ros2_path = workspace_path

func set_ai(ai_node: Node) -> void:
	_ai = ai_node

func generate_behavior(behavior_type: String, params: Dictionary = {}) -> void:
	if not _ai:
		behavior_generated.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured. Call set_ai(GameAI) first."}))
		return
	var system_prompt = """You are an expert in Godot 4 game development with GodotROS2 SDK integration.

Generate GDScript code that:
1. Creates a behavior node/class that works with GodotROS2
2. Subscribes to ROS topics (using GodotROS2's topic system)
3. Processes sensor data (lidar, camera, imu, etc.)
4. Makes decisions based on sensor input
5. Publishes commands (cmd_vel, joint commands)

The code should use Godot's Node system and integrate with ROS2Simulator, RobotModel, and sensor nodes.

Behavior types to implement:
- obstacle_avoid: Use lidar to detect and avoid obstacles
- wall_follow: Follow a wall at a constant distance
- line_follow: Follow a line using camera
- patrol: Move between waypoints
- chase: Chase a target object
- flee: Move away from threat

Return ONLY the GDScript code, no explanations."""
	var prompt = "Generate %s behavior" % behavior_type
	if params.size() > 0:
		prompt += " with params: %s" % str(params)
	var result = _ai.chat_system(system_prompt, prompt)
	behavior_generated.emit(result)

func generate_sensor_processor(sensor_type: String) -> void:
	if not _ai:
		sensor_processor_generated.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var system_prompt = """You are a Godot ROS 2 expert. Generate GDScript code that processes %s data from GodotROS2 sensors.

The code should:
1. Subscribe to the appropriate ROS topic
2. Process the raw data into useful information
3. Emit signals or update properties other nodes can use

Use Godot's signals for clean architecture.""" % sensor_type
	var prompt = "Process %s data and extract useful information" % sensor_type
	var result = _ai.chat_system(system_prompt, prompt)
	sensor_processor_generated.emit(result)

func generate_controller(controller_type: String) -> void:
	if not _ai:
		controller_generated.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var system_prompt = """Generate a GDScript motion controller for GodotROS2 robots.

Controller types:
- velocity: Control linear/angular velocity directly
- position: Move to target position using PID
- trajectory: Follow a planned trajectory
- force: Apply forces for physics-based control

Include:
- PID tuning parameters
- State management
- Error handling
- Safety limits (max speed, acceleration)

Use Vector3 for 3D vectors and Godot's physics engine."""
	var prompt = "Generate %s controller" % controller_type
	var result = _ai.chat_system(system_prompt, prompt)
	controller_generated.emit(result)

func explain_ros_topic(topic_name: String, message_type: String) -> void:
	if not _ai:
		topic_explained.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var prompt = """Explain this GodotROS2 / ROS topic:

Topic: %s
Message Type: %s

What data does it contain? How often is it published? What would you use it for?""" % [topic_name, message_type]
	var result = _ai.chat([{"role": "user", "content": prompt}])
	topic_explained.emit(result)

func diagnose_behavior_issue(symptoms: Array) -> void:
	if not _ai:
		diagnosis_completed.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var prompt = """My robot behavior isn't working correctly. Symptoms:

%s

What might be wrong? Consider:
- Topic subscriptions not connected
- Sensor data out of range
- Coordinate frame mismatches
- Physics collision issues
- ROS bridge not running

Provide diagnosis and fix suggestions in GDScript.""" % str(symptoms)
	var result = _ai.chat([{"role": "user", "content": prompt}])
	diagnosis_completed.emit(result)

func generate_state_machine(states: Array, transitions: Dictionary) -> void:
	if not _ai:
		state_machine_generated.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var prompt = """Create a GDScript state machine for a robot using GodotROS2.

States: %s
Transitions (state -> [next_states]): %s

Each state should:
- Be a separate class or inner class
- Have enter(), process(delta), and exit() methods
- Handle state-specific behavior
- Define valid transitions

Use signals to communicate between states.

Return ONLY GDScript code.""" % [str(states), str(transitions)]
	var result = _ai.chat([{"role": "user", "content": prompt}])
	state_machine_generated.emit(result)

func generate_vision_pipeline(task: String) -> void:
	if not _ai:
		vision_pipeline_generated.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var prompt = """Generate a GDScript vision processing pipeline for Godot + GodotROS2.

Task: %s

The pipeline should:
1. Subscribe to camera topic via GodotROS2
2. Process image using Godot's Image class
3. Extract features/objects/directions
4. Publish results or emit signals

Consider using Godot's built-in image processing or VisualShader.

Return GDScript code.""" % task
	var result = _ai.chat([{"role": "user", "content": prompt}])
	vision_pipeline_generated.emit(result)

func generate_waypoint_controller(waypoints: Array) -> void:
	if not _ai:
		waypoint_controller_generated.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var prompt = """Generate GDScript code for waypoint navigation in GodotROS2.

Waypoints: %s

The controller should:
1. Navigate to waypoint 0 first
2. Use velocity control (cmd_vel)
3. Detect arrival (within threshold)
4. Move to next waypoint
5. Loop or stop at end

Use Vector3 for positions and PID for smooth control.

Return GDScript code.""" % str(waypoints)
	var result = _ai.chat([{"role": "user", "content": prompt}])
	waypoint_controller_generated.emit(result)

func generate_multi_robot_logic(robot_count: int, task: String) -> void:
	if not _ai:
		multi_robot_logic_generated.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var prompt = """Generate GDScript for coordinating %d robots in GodotROS2.

Task: %s

Consider:
- ROS 2 topics for inter-robot communication
- Namespace per robot (e.g., /robot0, /robot1)
- Formation control
- Collision avoidance between robots
- Centralized vs decentralized coordination

Use Godot's scene system to spawn multiple robot instances.

Return GDScript code.""" % [robot_count, task]
	var result = _ai.chat([{"role": "user", "content": prompt}])
	multi_robot_logic_generated.emit(result)

func generate_robot_brain(robot_config: Dictionary) -> void:
	if not _ai:
		robot_brain_generated.emit(GameAIResult.new(false, null, {"code": -1, "message": "AI not configured"}))
		return
	var prompt = """Generate a complete "robot brain" GDScript class for GodotROS2.

Robot Config: %s

The brain should:
1. Initialize all sensors and their processors
2. Run behavior state machine
3. Handle high-level commands
4. Monitor robot health/status
5. Interface with ROS topics

Make it modular with inner classes for each subsystem.

Return GDScript code only.""" % str(robot_config)
	var result = _ai.chat([{"role": "user", "content": prompt}])
	robot_brain_generated.emit(result)