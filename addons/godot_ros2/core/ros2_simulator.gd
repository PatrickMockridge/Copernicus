# ros2_simulator.gd
# Main ROS 2 Simulator - Simple/Demo and Advanced modes

class_name ROS2Simulator

enum Mode { SIMPLE, ADVANCED }
enum PhysicsEngine { BUILTIN, EXTERNAL }

var _mode: Mode = Mode.SIMPLE
var _physics_engine: PhysicsEngine = PhysicsEngine.BUILTIN
var _world: SimulationWorld
var _robot_models: Dictionary = {}
var _sensors: Dictionary = {}
var _actuators: Dictionary = {}
var _plugins: Dictionary = {}
var _time_scale: float = 1.0
var _paused: bool = false
var _sim_time: float = 0.0
var _real_time: float = 0.0


func _init() -> void:
	_world = SimulationWorld.new()


# ===== Mode Selection =====

func set_mode(mode: Mode) -> void:
	_mode = mode
	print("ROS2 Simulator: Mode set to ", "SIMPLE" if mode == Mode.SIMPLE else "ADVANCED")


func get_mode() -> Mode:
	return _mode


func is_simple_mode() -> bool:
	return _mode == Mode.SIMPLE


func is_advanced_mode() -> bool:
	return _mode == Mode.ADVANCED


# ===== World Management =====

func get_world() -> SimulationWorld:
	return _world


func set_gravity(gravity: Vector3) -> void:
	_world.set_gravity(gravity)


func get_gravity() -> Vector3:
	return _world.get_gravity()


func set_world_time(step_size: float) -> void:
	_world.set_step_size(step_size)


# ===== Robot Models =====

func add_robot(robot: RobotModel) -> void:
	_robot_models[robot.get_name()] = robot
	_world.add_child(robot)


func get_robot(name: String) -> RobotModel:
	return _robot_models.get(name)


func remove_robot(name: String) -> void:
	if name in _robot_models:
		var robot = _robot_models[name]
		_world.remove_child(robot)
		_robot_models.erase(name)


func get_robot_names() -> Array:
	return _robot_models.keys()


# ===== Sensors =====

func add_sensor(sensor: Sensor) -> void:
	var sensor_name = sensor.get_name()
	_sensors[sensor_name] = sensor
	if sensor.get_robot():
		sensor.get_robot().add_child(sensor)


func get_sensor(name: String) -> Sensor:
	return _sensors.get(name)


func remove_sensor(name: String) -> void:
	if name in _sensors:
		_sensors.erase(name)


# ===== Actuators =====

func add_actuator(actuator: Actuator) -> void:
	var name = actuator.get_name()
	_actuators[name] = actuator
	if actuator.get_robot():
		actuator.get_robot().add_child(actuator)


func get_actuator(name: String) -> Actuator:
	return _actuators.get(name)


# ===== Physics =====

func set_physics_engine(engine: PhysicsEngine) -> void:
	_physics_engine = engine


func get_physics_engine() -> PhysicsEngine:
	return _physics_engine


func step_physics(delta: float) -> void:
	if _paused:
		return
	_world.step(delta * _time_scale)
	_sim_time += delta * _time_scale


# ===== Time Control =====

func set_time_scale(scale: float) -> void:
	_time_scale = max(0.0, scale)


func get_time_scale() -> float:
	return _time_scale


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


func get_sim_time() -> float:
	return _sim_time


func get_real_time() -> float:
	return _real_time


func reset() -> void:
	_sim_time = 0.0
	_world.reset()


# ===== Plugins =====

func load_plugin(plugin: SimulatorPlugin) -> void:
	var name = plugin.get_name()
	_plugins[name] = plugin
	plugin.on_load(self)


func unload_plugin(name: String) -> void:
	if name in _plugins:
		_plugins[name].on_unload()
		_plugins.erase(name)


func get_plugin(name: String) -> SimulatorPlugin:
	return _plugins.get(name)


# ===== State =====

func get_state() -> Dictionary:
	return {
		"mode": "simple" if _mode == Mode.SIMPLE else "advanced",
		"sim_time": _sim_time,
		"real_time": _real_time,
		"paused": _paused,
		"time_scale": _time_scale,
		"robot_count": _robot_models.size(),
		"sensor_count": _sensors.size(),
		"actuator_count": _actuators.size(),
		"plugin_count": _plugins.size()
	}


# ===== Simple Mode Helpers =====

func create_simple_robot(
	name: String,
	mesh_path: String = "",
	pose: Transform3D = Transform3D.IDENTITY
) -> RobotModel:
	var robot = RobotModel.new(name)
	robot.set_mode(RobotModel.Mode.SIMPLE)
	if not mesh_path.is_empty():
		robot.load_mesh_simple(mesh_path)
	robot.set_global_transform(pose)
	add_robot(robot)
	return robot


func create_simple_diff_robot(
	name: String,
	body_mesh: String = "",
	left_wheel: String = "",
	right_wheel: String = "",
	pose: Transform3D = Transform3D.IDENTITY
) -> RobotModel:
	var robot = create_simple_robot(name, body_mesh, pose)

	# Add differential drive
	var drive = DifferentialDrive.new("diff_drive")
	drive.set_wheel_separation(0.5)
	drive.set_wheel_radius(0.1)
	robot.add_drive_system(drive)

	# Add simple collision
	robot.set_use_collision(true)

	return robot


func add_lidar_to_robot(robot: RobotModel, name: String, config: Dictionary = {}) -> LidarSensor:
	var lidar = LidarSensor.new(name)
	lidar.configure(config)
	add_sensor(lidar)
	return lidar


func add_camera_to_robot(robot: RobotModel, name: String, config: Dictionary = {}) -> CameraSensor:
	var camera = CameraSensor.new(name)
	camera.configure(config)
	add_sensor(camera)
	return camera


func add_imu_to_robot(robot: RobotModel, name: String, config: Dictionary = {}) -> ImuSensor:
	var imu = ImuSensor.new(name)
	imu.configure(config)
	add_sensor(imu)
	return imu


# ===== Advanced Mode =====

func create_advanced_robot(
	name: String,
	urdf_path: String = "",
	pose: Transform3D = Transform3D.IDENTITY
) -> RobotModel:
	var robot = RobotModel.new(name)
	robot.set_mode(RobotModel.Mode.ADVANCED)
	if not urdf_path.is_empty():
		robot.load_urdf(urdf_path)
	robot.set_global_transform(pose)
	add_robot(robot)
	return robot


func create_articulated_robot(name: String, pose: Transform3D = Transform3D.IDENTITY) -> RobotModel:
	var robot = create_advanced_robot(name, "", pose)
	return robot


func add_joint_control(
	robot: RobotModel,
	joint_name: String,
	controller: JointController
) -> void:
	robot.add_joint_controller(joint_name, controller)


func enable_physics_debug() -> void:
	_world.enable_debug()


func get_contact_manager() -> ContactManager:
	return _world.get_contact_manager()
