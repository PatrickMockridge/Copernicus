# turtlebot4_loader.gd
# TurtleBot4 robot loader
# Supports loading from real DAE meshes or building from Godot primitives

class_name TurtleBot4Loader

enum MeshSource { MESHES, PRIMITIVES }

# TurtleBot4 geometry constants (from URDF)
const CREATE3_BODY_RADIUS = 0.164       # meters
const CREATE3_BODY_LENGTH = 0.06         # meters (height/width of cylinder)
const CREATE3_BODY_MASS = 2.3            # kg
const WHEEL_SEPARATION = 0.233          # meters (distance_between_wheels from URDF)
const WHEEL_RADIUS = 0.0419             # meters (Create3 wheel radius)
const SHELL_MASS = 0.390                # kg
const RPLIDAR_MASS = 0.17               # kg
const RPLIDAR_RANGE_MIN = 0.164         # meters
const RPLIDAR_RANGE_MAX = 12.0           # meters
const RPLIDAR_H_SAMPLES = 640           # horizontal samples

# Mesh paths
const TB4_MESH_BASE = "/opt/ros/jazzy/share/turtlebot4_description/meshes/"
const CREATE3_MESH_BASE = "/opt/ros/jazzy/share/irobot_create_description/meshes/"

# Origin offsets (from URDF)
const SHELL_Z_OFFSET = 0.03 + 0.0642    # 3*cm2m + base_link_z_offset (z offset + base height)
const RPLIDAR_X_OFFSET = -0.04
const RPLIDAR_Y_OFFSET = 0.0
const RPLIDAR_Z_OFFSET = 0.098715 + 0.03 + 0.0642  # rplidar_z_offset + shell_z_offset
const CAMERA_X_OFFSET = -0.118
const CAMERA_Y_OFFSET = 0.0
const CAMERA_Z_OFFSET = 0.05257 + 0.03 + 0.0642


static func load_turtlebot4(
	variant: String = "standard",
	source: MeshSource = MeshSource.MESHES
) -> RobotModel:
	"""
	Create a TurtleBot4 RobotModel.

	Args:
		variant: "standard" or "lite"
		source: MESHES to load DAE meshes, PRIMITIVES to build from Godot geometry

	Returns:
		RobotModel with all links, joints, and drive system configured
		(caller should add sensors via sim.add_*_to_robot and call sim.add_robot)
	"""
	match source:
		MeshSource.MESHES:
			return _create_from_meshes(variant)
		MeshSource.PRIMITIVES:
			return _create_from_primitives(variant)
	return null


static func _create_from_meshes(variant: String) -> RobotModel:
	var robot = RobotModel.new("turtlebot4")
	robot.set_mode(RobotModel.Mode.ADVANCED)

	var mesh_warn: bool = false

	# === Create3 Base ===
	var base_link = _make_link(robot, "base_link", CREATE3_BODY_MASS, Vector3.ONE, "base_link")

	# Load body mesh
	var body_mesh_path = CREATE3_MESH_BASE + "body_visual.dae"
	if FileAccess.file_exists(body_mesh_path):
		var body_mesh = _load_dae_mesh(body_mesh_path)
		if body_mesh:
			base_link.set_visual_mesh(body_mesh)
		else:
			if not mesh_warn:
				print("TurtleBot4Loader: Could not load body mesh, using primitive")
				mesh_warn = true
	else:
		if not mesh_warn:
			print("TurtleBot4Loader: Body mesh not found at %s, using primitive" % body_mesh_path)
			mesh_warn = true

	# Cylinder collision for base
	var base_cyl = CylinderShape3D.new()
	base_cyl.radius = CREATE3_BODY_RADIUS
	base_cyl.height = CREATE3_BODY_LENGTH
	base_link.set_collision_shape(base_cyl)

	# === Wheels (Primitive - no wheel mesh in packages) ===
	var drive = DifferentialDrive.new("diff_drive")
	drive.set_wheel_separation(WHEEL_SEPARATION)
	drive.set_wheel_radius(WHEEL_RADIUS)
	drive.set_robot(robot.get_node())

	var left_wheel = _make_wheel_mesh("left_wheel")
	var right_wheel = _make_wheel_mesh("right_wheel")

	var wheel_offset_l = Vector3(0, -WHEEL_SEPARATION / 2, 0)
	var wheel_offset_r = Vector3(0, WHEEL_SEPARATION / 2, 0)

	# Place wheels relative to base (simplified - at body level)
	left_wheel.set_transform(left_wheel.get_transform().translated(wheel_offset_l))
	right_wheel.set_transform(right_wheel.get_transform().translated(wheel_offset_r))

	base_link.get_node().add_child(left_wheel)
	base_link.get_node().add_child(right_wheel)

	robot.add_drive_system(drive)

	# === Shell ===
	var shell_link = _make_link(robot, "shell_link", SHELL_MASS, Vector3(0.0028, 0.0016, 0.0042), "shell_link")
	shell_link.get_node().set_position(Vector3(0, 0, SHELL_Z_OFFSET))

	var shell_mesh_path = TB4_MESH_BASE + "shell.dae"
	if FileAccess.file_exists(shell_mesh_path):
		var shell_mesh = _load_dae_mesh(shell_mesh_path)
		if shell_mesh:
			shell_mesh.set_name("shell_visual")
			shell_link.set_visual_mesh(shell_mesh)
		else:
			_add_primitive_visual(shell_link, BoxMesh.new(), Vector3(0.24, 0.01, 0.24))

	var shell_collision = BoxShape3D.new()
	shell_collision.size = Vector3(0.24, 0.01, 0.24)
	shell_link.set_collision_shape(shell_collision)

	# === Tower Standoffs + Sensor Plate ===
	var tower_link = _make_link(robot, "tower_link", 0.1, Vector3.ONE, "tower_link")
	tower_link.get_node().set_position(Vector3(0, 0, 0.148))

	var tower_mesh_path = TB4_MESH_BASE + "tower.dae"
	if FileAccess.file_exists(tower_mesh_path):
		var tower_mesh = _load_dae_mesh(tower_mesh_path)
		if tower_mesh:
			tower_mesh.set_name("tower_visual")
			tower_link.set_visual_mesh(tower_mesh)

	# === RPLidar ===
	var lidar_link = _make_link(robot, "rplidar_link", RPLIDAR_MASS, Vector3.ONE, "rplidar_link")
	lidar_link.get_node().set_position(Vector3(RPLIDAR_X_OFFSET, RPLIDAR_Y_OFFSET, RPLIDAR_Z_OFFSET))

	var lidar_mesh_path = TB4_MESH_BASE + "rplidar.dae"
	if FileAccess.file_exists(lidar_mesh_path):
		var lidar_mesh = _load_dae_mesh(lidar_mesh_path)
		if lidar_mesh:
			lidar_mesh.set_name("rplidar_visual")
			lidar_link.set_visual_mesh(lidar_mesh)
	else:
		_add_primitive_visual(lidar_link, CylinderMesh.new(), Vector3(0.05, 0.06, 0.05))

	var lidar_collision = BoxShape3D.new()
	lidar_collision.size = Vector3(0.071, 0.06, 0.10)
	lidar_link.set_collision_shape(lidar_collision)

	# Add Lidar sensor
	var lidar: LidarSensor
	lidar = LidarSensor.new("rplidar")
	lidar.configure({
		"angle_min": -PI,
		"angle_max": PI,
		"range_min": RPLIDAR_RANGE_MIN,
		"range_max": RPLIDAR_RANGE_MAX,
		"h_samples": RPLIDAR_H_SAMPLES,
		"update_rate": 62.0,
		"frame_id": "rplidar_link"
	})
	lidar_link.get_node().add_child(lidar)

	# === Oak-D Camera ===
	var camera_link = _make_link(robot, "oakd_link", 0.061, Vector3(0.000002, 0.000015, 0.000016), "oakd_link")
	camera_link.get_node().set_position(Vector3(CAMERA_X_OFFSET, CAMERA_Y_OFFSET, CAMERA_Z_OFFSET))

	var camera_mesh_path = TB4_MESH_BASE + "oakd_pro.dae"
	if FileAccess.file_exists(camera_mesh_path):
		var camera_mesh = _load_dae_mesh(camera_mesh_path)
		if camera_mesh:
			camera_mesh.set_name("oakd_visual")
			camera_link.set_visual_mesh(camera_mesh)

	var camera_collision = BoxShape3D.new()
	camera_collision.size = Vector3(0.0225, 0.097, 0.03)
	camera_link.set_collision_shape(camera_collision)

	var camera: CameraSensor
	camera = CameraSensor.new("oakd")
	camera.configure({
		"fov": 1.047,
		"width": 640,
		"height": 480,
		"frame_id": "oakd_rgb_camera_optical_frame"
	})
	camera_link.get_node().add_child(camera)

	# === IMU ===
	var imu_link = _make_link(robot, "imu_link", 0.001, Vector3.ONE, "imu_link")
	imu_link.get_node().set_position(Vector3(0, 0, 0.0642))  # In the base

	var imu: ImuSensor
	imu = ImuSensor.new("imu")
	imu.configure({"frame_id": "imu_link"})
	imu_link.get_node().add_child(imu)

	return robot


static func _create_from_primitives(variant: String) -> RobotModel:
	var robot = RobotModel.new("turtlebot4")
	robot.set_mode(RobotModel.Mode.ADVANCED)

	# === Create3 Base (Cylinder) ===
	var base_link = _make_link(robot, "base_link", CREATE3_BODY_MASS, Vector3.ONE, "base_link")

	var base_cyl_shape = CylinderShape3D.new()
	base_cyl_shape.radius = CREATE3_BODY_RADIUS
	base_cyl_shape.height = CREATE3_BODY_LENGTH
	base_link.set_collision_shape(base_cyl_shape)

	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = CREATE3_BODY_RADIUS
	base_mesh.bottom_radius = CREATE3_BODY_RADIUS
	base_mesh.height = CREATE3_BODY_LENGTH
	_add_primitive_visual(base_link, base_mesh, Vector3())

	# === Differential Drive + Wheels ===
	var drive = DifferentialDrive.new("diff_drive")
	drive.set_wheel_separation(WHEEL_SEPARATION)
	drive.set_wheel_radius(WHEEL_RADIUS)
	drive.set_robot(robot.get_node())

	# Left wheel (box)
	var left_wheel_mesh = BoxMesh.new()
	left_wheel_mesh.size = Vector3(0.02, 0.08, WHEEL_RADIUS * 2)
	var left_wheel_node = Node3D.new()
	left_wheel_node.set_name("left_wheel")
	var left_wheel_visual = MeshInstance3D.new()
	left_wheel_visual.set_mesh(left_wheel_mesh)
	left_wheel_node.add_child(left_wheel_visual)
	left_wheel_node.set_position(Vector3(0, -WHEEL_SEPARATION / 2, -CREATE3_BODY_LENGTH / 2))
	base_link.get_node().add_child(left_wheel_node)

	# Right wheel (box)
	var right_wheel_mesh = BoxMesh.new()
	right_wheel_mesh.size = Vector3(0.02, 0.08, WHEEL_RADIUS * 2)
	var right_wheel_node = Node3D.new()
	right_wheel_node.set_name("right_wheel")
	var right_wheel_visual = MeshInstance3D.new()
	right_wheel_visual.set_mesh(right_wheel_mesh)
	right_wheel_node.add_child(right_wheel_visual)
	right_wheel_node.set_position(Vector3(0, WHEEL_SEPARATION / 2, -CREATE3_BODY_LENGTH / 2))
	base_link.get_node().add_child(right_wheel_node)

	# Caster wheel (sphere)
	var caster_shape = SphereShape3D.new()
	caster_shape.radius = 0.02
	var caster_node = Node3D.new()
	caster_node.set_name("caster")
	var caster_visual = MeshInstance3D.new()
	var caster_mesh = SphereMesh.new()
	caster_mesh.radius = 0.02
	caster_mesh.height = 0.04
	caster_visual.set_mesh(caster_mesh)
	caster_node.add_child(caster_visual)
	caster_node.set_position(Vector3(0.125, 0, -CREATE3_BODY_LENGTH / 2))
	base_link.get_node().add_child(caster_node)

	robot.add_drive_system(drive)

	# === Shell (Box on top) ===
	var shell_link = _make_link(robot, "shell_link", SHELL_MASS, Vector3.ONE, "shell_link")
	shell_link.get_node().set_position(Vector3(0, 0, SHELL_Z_OFFSET))

	var shell_mesh = BoxMesh.new()
	shell_mesh.size = Vector3(0.24, 0.24, 0.01)
	_add_primitive_visual(shell_link, shell_mesh, Vector3())

	var shell_collision = BoxShape3D.new()
	shell_collision.size = Vector3(0.24, 0.24, 0.01)
	shell_link.set_collision_shape(shell_collision)

	# === Tower (thin box) ===
	var tower_link = _make_link(robot, "tower_link", 0.1, Vector3.ONE, "tower_link")
	tower_link.get_node().set_position(Vector3(0, 0, 0.148))

	var tower_mesh = BoxMesh.new()
	tower_mesh.size = Vector3(0.02, 0.02, 0.10)
	_add_primitive_visual(tower_link, tower_mesh, Vector3())

	# === Sensor Plate ===
	var plate_link = _make_link(robot, "sensor_plate_link", 0.05, Vector3.ONE, "sensor_plate_link")
	plate_link.get_node().set_position(Vector3(0, 0, 0.252))

	var plate_mesh = BoxMesh.new()
	plate_mesh.size = Vector3(0.10, 0.10, 0.005)
	_add_primitive_visual(plate_link, plate_mesh, Vector3())

	# === RPLidar (Cylinder) ===
	var lidar_link = _make_link(robot, "rplidar_link", RPLIDAR_MASS, Vector3.ONE, "rplidar_link")
	lidar_link.get_node().set_position(Vector3(RPLIDAR_X_OFFSET, RPLIDAR_Y_OFFSET, RPLIDAR_Z_OFFSET))

	var lidar_mesh = CylinderMesh.new()
	lidar_mesh.top_radius = 0.035
	lidar_mesh.bottom_radius = 0.035
	lidar_mesh.height = 0.06
	_add_primitive_visual(lidar_link, lidar_mesh, Vector3())

	var lidar_collision = CylinderShape3D.new()
	lidar_collision.radius = 0.035
	lidar_collision.height = 0.06
	lidar_link.set_collision_shape(lidar_collision)

	var lidar: LidarSensor
	lidar = LidarSensor.new("rplidar")
	lidar.configure({
		"angle_min": -PI,
		"angle_max": PI,
		"range_min": RPLIDAR_RANGE_MIN,
		"range_max": RPLIDAR_RANGE_MAX,
		"h_samples": RPLIDAR_H_SAMPLES,
		"update_rate": 62.0,
		"frame_id": "rplidar_link"
	})
	lidar_link.get_node().add_child(lidar)

	# === Oak-D Camera (Box) ===
	var camera_link = _make_link(robot, "oakd_link", 0.061, Vector3.ONE, "oakd_link")
	camera_link.get_node().set_position(Vector3(CAMERA_X_OFFSET, CAMERA_Y_OFFSET, CAMERA_Z_OFFSET))

	var camera_mesh = BoxMesh.new()
	camera_mesh.size = Vector3(0.03, 0.097, 0.0225)
	_add_primitive_visual(camera_link, camera_mesh, Vector3())

	var camera_collision = BoxShape3D.new()
	camera_collision.size = Vector3(0.03, 0.097, 0.0225)
	camera_link.set_collision_shape(camera_collision)

	var camera: CameraSensor
	camera = CameraSensor.new("oakd")
	camera.configure({
		"fov": 1.047,
		"width": 640,
		"height": 480,
		"frame_id": "oakd_rgb_camera_optical_frame"
	})
	camera_link.get_node().add_child(camera)

	# === IMU ===
	var imu_link = _make_link(robot, "imu_link", 0.001, Vector3.ONE, "imu_link")
	imu_link.get_node().set_position(Vector3(0, 0, 0.0642))

	var imu: ImuSensor
	imu = ImuSensor.new("imu")
	imu.configure({"frame_id": "imu_link"})
	imu_link.get_node().add_child(imu)

	return robot


static func _make_link(robot: RobotModel, name: String, mass: float, inertia: Vector3, node_name: String) -> RobotLink:
	var link = RobotLink.new(name)
	link.set_name(name)
	link.set_mass(mass)
	link.set_inertia(inertia)
	link.set_root(node_name == "base_link")
	robot.add_link(link)
	return link


static func _make_wheel_mesh(wheel_name: String) -> Node3D:
	var wheel_node = Node3D.new()
	wheel_node.set_name(wheel_name)

	var wheel_mesh = CylinderMesh.new()
	wheel_mesh.top_radius = WHEEL_RADIUS
	wheel_mesh.bottom_radius = WHEEL_RADIUS
	wheel_mesh.height = 0.02

	var visual = MeshInstance3D.new()
	visual.set_mesh(wheel_mesh)
	visual.set_name("visual")
	wheel_node.add_child(visual)

	# Rotate so cylinder axis is along X (wheel spins around X)
	var t = wheel_node.get_transform()
	t.basis = Basis(Vector3(1, 0, 0), PI / 2)
	wheel_node.set_transform(t)

	return wheel_node


static func _load_dae_mesh(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null

	var resource = load(path)
	if resource == null:
		return null

	# DAE loaded as PackedScene or Mesh
	if resource is PackedScene:
		return resource.instantiate()
	elif resource is Mesh:
		var mi = MeshInstance3D.new()
		mi.set_mesh(resource)
		return mi

	return null


static func _add_primitive_visual(link: RobotLink, mesh: Mesh, offset: Vector3) -> void:
	var mi = MeshInstance3D.new()
	mi.set_name("visual")
	mi.set_mesh(mesh)
	mi.set_position(offset)
	link.get_node().add_child(mi)
