# ros_ai.gd
# GameAI + GodotROS2 Integration - AI for robotics in Godot
# Uses GameAI to generate behaviors/logic for use with GodotROS2 SDK

extends Node

class_name ROSAIBehavior

const Result = preload("res://addons/GameAI/core/result.gd")

## ROSAIBehavior - AI Assistant for GodotROS2
##
## Generate behaviors, debug issues, and extend your robots with AI
## Works WITH GodotROS2 SDK (doesn't replace it)
##
## Usage:
## var ros_ai = ROSAIBehavior.new()
## ros_ai.set_godot_ros2("/root/ros2_ws")
## var code = await ros_ai.generate_behavior("obstacle_avoid")

var _ros2_path: String = ""
var _ai: Node = null


func set_godot_ros2(workspace_path: String) -> void:
	_ros2_path = workspace_path


func set_ai(ai_node: Node) -> void:
	_ai = ai_node


# === Behavior Generation for GodotROS2 ===

async func generate_behavior(behavior_type: String, params: Dictionary = {}) -> Result:
	# Generate robot behavior code for GodotROS2
	# behavior_type: "wall_follow", "line_follow", "obstacle_avoid", "patrol", "chase", "flee"

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

	if _ai:
		return await _ai.chat_system(system_prompt, prompt)
	return Result.err({"code": -1, "message": "AI not configured. Call set_ai(GameAI) first."})


async func generate_sensor_processor(sensor_type: String) -> Result:
	# Generate code to process specific sensor data
	var system_prompt = """You are a Godot ROS 2 expert. Generate GDScript code that processes %s data from GodotROS2 sensors.

The code should:
1. Subscribe to the appropriate ROS topic
2. Process the raw data into useful information
3. Emit signals or update properties other nodes can use

Use Godot's signals for clean architecture.""" % sensor_type

	var prompt = "Process %s data and extract useful information" % sensor_type

	if _ai:
		return await _ai.chat_system(system_prompt, prompt)
	return Result.err({"code": -1, "message": "AI not configured"})


async func generate_controller(controller_type: String) -> Result:
	# Generate motion controller code
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

	if _ai:
		return await _ai.chat_system(system_prompt, prompt)
	return Result.err({"code": -1, "message": "AI not configured"})


# === Debugging & Explanation ===

async func explain_ros_topic(topic_name: String, message_type: String) -> Result:
	# Explain a ROS topic/message
	var prompt = """Explain this GodotROS2 / ROS topic:

Topic: %s
Message Type: %s

What data does it contain? How often is it published? What would you use it for?""" % [topic_name, message_type]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


async func diagnose_behavior_issue(symptoms: Array) -> Result:
	# Debug why a behavior isn't working
	var prompt = """My robot behavior isn't working correctly. Symptoms:

%s

What might be wrong? Consider:
- Topic subscriptions not connected
- Sensor data out of range
- Coordinate frame mismatches
- Physics collision issues
- ROS bridge not running

Provide diagnosis and fix suggestions in GDScript.""" % str(symptoms)

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === State Machines & AI ===

async func generate_state_machine(states: Array, transitions: Dictionary) -> Result:
	# Generate behavior state machine
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

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Vision Processing ===

async func generate_vision_pipeline(task: String) -> Result:
	# Generate computer vision pipeline
	var prompt = """Generate a GDScript vision processing pipeline for Godot + GodotROS2.

Task: %s

The pipeline should:
1. Subscribe to camera topic via GodotROS2
2. Process image using Godot's Image class
3. Extract features/objects/directions
4. Publish results or emit signals

Consider using Godot's built-in image processing or VisualShader.

Return GDScript code.""" % task

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Navigation ===

async func generate_waypoint_controller(waypoints: Array) -> Result:
	# Generate waypoint navigation
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

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Multi-Robot Coordination ===

async func generate_multi_robot_logic(robot_count: int, task: String) -> Result:
	# Generate multi-robot coordination logic
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

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Complete Robot Brain ===

async func generate_robot_brain(robot_config: Dictionary) -> Result:
	# Generate complete AI brain for a robot
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

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})
