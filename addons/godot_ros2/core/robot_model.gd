# robot_model.gd
# Robot model for simulation

class_name RobotModel

enum Mode { SIMPLE, ADVANCED }
enum ControlMode { POSITION, VELOCITY, EFFORT }

var _name: String
var _mode: Mode = Mode.SIMPLE
var _control_mode: ControlMode = ControlMode.VELOCITY
var _links: Dictionary = {}
var _joints: Dictionary = {}
var _drive_system: Node
var _mesh: Node3D
var _collision: CollisionShape3D
var _robot_node: Node3D
var _joint_controllers: Dictionary = {}


func _init(name: String) -> void:
	_name = name
	_robot_node = Node3D.new()
	_robot_node.set_name(name)


func _to_string() -> String:
	return "RobotModel:%s" % _name


# ===== Basic Properties =====

func get_name() -> String:
	return _name


func set_mode(mode: Mode) -> void:
	_mode = mode


func get_mode() -> Mode:
	return _mode


func get_node() -> Node3D:
	return _robot_node


# ===== Links =====

func add_link(link: RobotLink) -> void:
	_links[link.get_name()] = link
	_robot_node.add_child(link.get_node())


func get_link(name: String) -> RobotLink:
	return _links.get(name)


func get_links() -> Array:
	return _links.values()


func get_root_link() -> RobotLink:
	for link in _links.values():
		if link.is_root():
			return link
	return null


# ===== Joints =====

func add_joint(joint: RobotJoint) -> void:
	_joints[joint.get_name()] = joint
	_robot_node.add_child(joint.get_node())


func get_joint(name: String) -> RobotJoint:
	return _joints.get(name)


func get_joints() -> Array:
	return _joints.values()


# ===== Mesh =====

func load_mesh_simple(path: String) -> void:
	if FileAccess.file_exists(path):
		var mesh = load(path)
		if mesh:
			_mesh = mesh.instantiate()
			_robot_node.add_child(_mesh)


func set_mesh(mesh: Node3D) -> void:
	if _mesh:
		_robot_node.remove_child(_mesh)
	_mesh = mesh
	_robot_node.add_child(_mesh)


func get_mesh() -> Node3D:
	return _mesh


# ===== Collision =====

func set_use_collision(enabled: bool) -> void:
	if enabled and not _collision:
		_collision = CollisionShape3D.new()
		_robot_node.add_child(_collision)


func set_collision_shape(shape: Shape3D) -> void:
	if _collision:
		_collision.set_shape(shape)


# ===== Drive System =====

func add_drive_system(drive: Node) -> void:
	_drive_system = drive
	_robot_node.add_child(drive)


func get_drive_system() -> Node:
	return _drive_system


func set_control_mode(mode: ControlMode) -> void:
	_control_mode = mode


func get_control_mode() -> ControlMode:
	return _control_mode


# ===== Joint Controllers =====

func add_joint_controller(joint_name: String, controller: JointController) -> void:
	_joint_controllers[joint_name] = controller
	var joint = get_joint(joint_name)
	if joint:
		controller.set_joint(joint)


# ===== URDF Loading (Advanced) =====

func load_urdf(urdf_path: String) -> void:
	if not FileAccess.file_exists(urdf_path):
		push_warning("URDF file not found: %s" % urdf_path)
		return

	# In advanced mode, parse URDF and create links/joints
	if _mode == Mode.ADVANCED:
		_parse_urdf(urdf_path)


func _parse_urdf(path: String) -> void:
	var parser = XMLParser.new()
	var err = parser.open(path)
	if err != OK:
		push_warning("RobotModel: Failed to open URDF: " + path)
		return

	var link_data: Dictionary = {}
	var joint_data: Array = []
	var current_element = ""
	var current_link_name = ""

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node_name = parser.get_node_name()

				if node_name == "link":
					current_link_name = parser.get_named_attribute_value_safe("name")
					current_element = "link"
					link_data[current_link_name] = {
						"mass": 1.0,
						"inertia": Vector3.ONE,
						"visual_mesh_path": "",
						"collision_type": "",
						"collision_params": {},
						"origin_xyz": Vector3.ZERO,
						"origin_rpy": Vector3.ZERO
					}
				elif node_name == "joint":
					current_element = "joint"
					joint_data.append({
						"name": parser.get_named_attribute_value_safe("name"),
						"type": parser.get_named_attribute_value_safe("type"),
						"parent": "",
						"child": "",
						"axis_xyz": Vector3(1, 0, 0),
						"origin_xyz": Vector3.ZERO,
						"origin_rpy": Vector3.ZERO,
						"limit_lower": -INF,
						"limit_upper": INF,
						"limit_effort": INF,
						"limit_velocity": INF
					})
				elif node_name == "parent":
					if current_element == "joint" and joint_data.size() > 0:
						joint_data[joint_data.size() - 1]["parent"] = parser.get_named_attribute_value_safe("link")
				elif node_name == "child":
					if current_element == "joint" and joint_data.size() > 0:
						joint_data[joint_data.size() - 1]["child"] = parser.get_named_attribute_value_safe("link")
				elif node_name == "axis":
					if current_element == "joint" and joint_data.size() > 0:
						var xyz = parser.get_named_attribute_value_safe("xyz")
						joint_data[joint_data.size() - 1]["axis_xyz"] = _parse_xyz(xyz)
				elif node_name == "origin":
					if current_element == "link":
						var xyz = parser.get_named_attribute_value_safe("xyz")
						var rpy = parser.get_named_attribute_value_safe("rpy")
						link_data[current_link_name]["origin_xyz"] = _parse_xyz(xyz)
						link_data[current_link_name]["origin_rpy"] = _parse_rpy(rpy)
					elif current_element == "joint" and joint_data.size() > 0:
						var xyz = parser.get_named_attribute_value_safe("xyz")
						var rpy = parser.get_named_attribute_value_safe("rpy")
						joint_data[joint_data.size() - 1]["origin_xyz"] = _parse_xyz(xyz)
						joint_data[joint_data.size() - 1]["origin_rpy"] = _parse_rpy(rpy)
				elif node_name == "limit":
					if current_element == "joint" and joint_data.size() > 0:
						var j = joint_data[joint_data.size() - 1]
						var lower_str = parser.get_named_attribute_value_safe("lower")
						var upper_str = parser.get_named_attribute_value_safe("upper")
						var effort_str = parser.get_named_attribute_value_safe("effort")
						var velocity_str = parser.get_named_attribute_value_safe("velocity")
						if not lower_str.is_empty():
							j["limit_lower"] = float(lower_str)
						if not upper_str.is_empty():
							j["limit_upper"] = float(upper_str)
						if not effort_str.is_empty():
							j["limit_effort"] = float(effort_str)
						if not velocity_str.is_empty():
							j["limit_velocity"] = float(velocity_str)
				elif node_name == "mass":
					if current_element == "link" and link_data.has(current_link_name):
						var value = parser.get_named_attribute_value_safe("value")
						if not value.is_empty():
							link_data[current_link_name]["mass"] = float(value)
				elif node_name == "inertia":
					if current_element == "link" and link_data.has(current_link_name):
						var ixx = parser.get_named_attribute_value_safe("ixx")
						var iyy = parser.get_named_attribute_value_safe("iyy")
						var izz = parser.get_named_attribute_value_safe("izz")
						if not ixx.is_empty() and not iyy.is_empty() and not izz.is_empty():
							link_data[current_link_name]["inertia"] = Vector3(float(ixx), float(iyy), float(izz))
				elif node_name == "mesh":
					if current_element == "link":
						var filename = parser.get_named_attribute_value_safe("filename")
						if not filename.is_empty():
							link_data[current_link_name]["visual_mesh_path"] = _resolve_mesh_path(filename)
				elif node_name == "box":
					if current_element == "link":
						var size = parser.get_named_attribute_value_safe("size")
						if not size.is_empty():
							link_data[current_link_name]["collision_type"] = "box"
							link_data[current_link_name]["collision_params"] = {"size": _parse_xyz(size)}
				elif node_name == "cylinder":
					if current_element == "link":
						var length = parser.get_named_attribute_value_safe("length")
						var radius = parser.get_named_attribute_value_safe("radius")
						if not length.is_empty() and not radius.is_empty():
							link_data[current_link_name]["collision_type"] = "cylinder"
							link_data[current_link_name]["collision_params"] = {"length": float(length), "radius": float(radius)}
				elif node_name == "sphere":
					if current_element == "link":
						var radius = parser.get_named_attribute_value_safe("radius")
						if not radius.is_empty():
							link_data[current_link_name]["collision_type"] = "sphere"
							link_data[current_link_name]["collision_params"] = {"radius": float(radius)}

			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() in ["link", "joint"]:
					current_element = ""

	# Build links
	var link_nodes: Dictionary = {}
	for link_name in link_data:
		var data = link_data[link_name]
		var link = RobotLink.new(link_name)
		link.set_mass(data["mass"])
		link.set_inertia(data["inertia"])

		# Set visual mesh if available
		if not data["visual_mesh_path"].is_empty() and FileAccess.file_exists(data["visual_mesh_path"]):
			var mesh = load(data["visual_mesh_path"])
			if mesh:
				var mesh_instance = mesh.instantiate()
				mesh_instance.set_name("visual")
				link.set_visual_mesh(mesh_instance)

		# Set collision shape
		var collision_shape: Shape3D
		match data["collision_type"]:
			"box":
				var p = data["collision_params"]
				collision_shape = BoxShape3D.new()
				collision_shape.size = p["size"]
			"cylinder":
				var p = data["collision_params"]
				collision_shape = CylinderShape3D.new()
				collision_shape.height = p["length"]
				collision_shape.radius = p["radius"]
			"sphere":
				var p = data["collision_params"]
				collision_shape = SphereShape3D.new()
				collision_shape.radius = p["radius"]
		if collision_shape:
			link.set_collision_shape(collision_shape)

		add_link(link)
		link_nodes[link_name] = link

	# Find root link (link that is not a child of any joint)
	var child_links: Array = []
	for j in joint_data:
		child_links.append(j["child"])

	var root_link_name = ""
	for link_name in link_data:
		if link_name not in child_links:
			root_link_name = link_name
			break

	if root_link_name.is_empty() and link_data.size() > 0:
		root_link_name = link_data.keys()[0]

	if not root_link_name.is_empty() and link_nodes.has(root_link_name):
		link_nodes[root_link_name].set_root(true)

	# Build joints and hierarchy
	for j in joint_data:
		var joint = RobotJoint.new(j["name"])

		# Map URDF joint type to RobotJoint.JointType
		match j["type"]:
			"revolute":
				joint.set_type(RobotJoint.JointType.REVOLUTE)
			"continuous":
				joint.set_type(RobotJoint.JointType.CONTINUOUS)
			"prismatic":
				joint.set_type(RobotJoint.JointType.PRISMATIC)
			"fixed":
				joint.set_type(RobotJoint.JointType.FIXED)
			"planar":
				joint.set_type(RobotJoint.JointType.PLANAR)
			"floating":
				joint.set_type(RobotJoint.JointType.FLOATING)

		joint.set_parent_link(j["parent"])
		joint.set_child_link(j["child"])
		joint.set_axis(j["axis_xyz"])
		joint.set_limits(j["limit_lower"], j["limit_upper"])

		# Set joint origin transform
		var joint_node = joint.get_node()
		var origin_t = Transform3D()
		origin_t = origin_t.translated(j["origin_xyz"])
		var rpy = j["origin_rpy"]
		if rpy.length() > 0.001:
			var rot = Basis()
			rot = rot.rotated(Vector3(1, 0, 0), rpy.x)
			rot = rot.rotated(Vector3(0, 1, 0), rpy.y)
			rot = rot.rotated(Vector3(0, 0, 1), rpy.z)
			origin_t.basis = rot
		joint_node.transform = origin_t

		add_joint(joint)

		# Reparent child link under joint node
		if link_nodes.has(j["child"]):
			var child_link_node = link_nodes[j["child"]].get_node()
			var parent_link_node: Node3D
			if link_nodes.has(j["parent"]):
				parent_link_node = link_nodes[j["parent"]].get_node()
				# Remove child from robot root, add under parent link
				_robot_node.remove_child(child_link_node)
				parent_link_node.add_child(joint_node)
				joint_node.add_child(child_link_node)

	print("RobotModel: Loaded %d links, %d joints from URDF" % [link_data.size(), joint_data.size()])


func _parse_xyz(xyz_str: String) -> Vector3:
	if xyz_str.is_empty():
		return Vector3.ZERO
	var parts = xyz_str.split(" ")
	if parts.size() < 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _parse_rpy(rpy_str: String) -> Vector3:
	# URDF rpy is in radians
	if rpy_str.is_empty():
		return Vector3.ZERO
	var parts = rpy_str.split(" ")
	if parts.size() < 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _resolve_mesh_path(uri: String) -> String:
	# Handle package:// URLs: package://package_name/path -> /opt/ros/<distro>/share/package_name/path
	# or resolve via ament_prefix
	if uri.begins_with("package://"):
		var remainder = uri.substr(10)  # remove "package://"
		var slash_idx = remainder.find("/")
		if slash_idx == -1:
			return ""
		var package_name = remainder.substr(0, slash_idx)
		var file_path = remainder.substr(slash_idx)

		# Try common ROS install prefixes
		var prefixes = [
			"/opt/ros/jazzy/share/" + package_name + file_path,
			"/opt/ros/humble/share/" + package_name + file_path,
			"/home/" + OS.get_environment("USER") + "/ros2_ws/install/share/" + package_name + file_path,
			"/home/" + OS.get_environment("USER") + "/ros2_ws/build/" + package_name + file_path,
		]
		for prefix in prefixes:
			if FileAccess.file_exists(prefix):
				return prefix

		# Try to find via ament prefix
		var ament_prefix = _get_ament_prefix(package_name)
		if not ament_prefix.is_empty():
			var full_path = ament_prefix + "/share/" + package_name + file_path
			if FileAccess.file_exists(full_path):
				return full_path

	return uri


func _get_ament_prefix(package_name: String) -> String:
	# Try to read the package's share directory from ament index
	var ament_index = "/opt/ros/jazzy/share/ament_index/resource_index/packages"
	if DirAccess.dir_exists_absolute(ament_index):
		var resource_path = ament_index + "/" + package_name
		if DirAccess.dir_exists_absolute(resource_path):
			return "/opt/ros/jazzy/share"
	return ""


# ===== Transform =====

func set_global_transform(transform: Transform3D) -> void:
	_robot_node.set_global_transform(transform)


func get_global_transform() -> Transform3D:
	return _robot_node.get_global_transform()


func get_pose() -> Dictionary:
	var t = get_global_transform()
	return {
		"position": t.origin,
		"orientation": t.basis.get_rotation_quaternion()
	}


# ===== State =====

func get_state() -> Dictionary:
	return {
		"name": _name,
		"mode": "simple" if _mode == Mode.SIMPLE else "advanced",
		"links": _links.keys(),
		"joints": _joints.keys(),
		"pose": get_pose()
	}
