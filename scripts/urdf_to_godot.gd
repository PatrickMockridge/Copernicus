# urdf_to_godot.gd
# URDF parser that creates Godot native scene tree
# Uses MeshInstance3D, Skeleton3D, CollisionShape3D instead of custom classes

class_name URDFToGodot

# Parse URDF and return a Godot Node3D scene tree
static func parse(urdf_path: String) -> Node3D:
	if not FileAccess.file_exists(urdf_path):
		push_error("URDFToGodot: File not found: " + urdf_path)
		return null

	var parser = XMLParser.new()
	var err = parser.open(urdf_path)
	if err != OK:
		push_error("URDFToGodot: Failed to open URDF: " + urdf_path)
		return null

	var link_data: Dictionary = {}
	var joint_data: Array = []
	var current_element = ""
	var current_link_name = ""

	# Parse URDF XML
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
						"origin_rpy": Vector3.ZERO,
						"material_color": Color(0.8, 0.8, 0.8)
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
						if not lower_str.is_empty():
							j["limit_lower"] = float(lower_str)
						if not upper_str.is_empty():
							j["limit_upper"] = float(upper_str)
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
				elif node_name == "material":
					if current_element == "link":
						var color_str = parser.get_named_attribute_value_safe("color")
						if not color_str.is_empty():
							var parts = color_str.split(" ")
							if parts.size() >= 3:
								link_data[current_link_name]["material_color"] = Color(float(parts[0]), float(parts[1]), float(parts[2]))

			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() in ["link", "joint"]:
					current_element = ""

	# Build Godot scene tree
	return _build_scene_tree(link_data, joint_data)


static func _build_scene_tree(link_data: Dictionary, joint_data: Array) -> Node3D:
	var root = Node3D.new()
	root.set_name("Robot")
	root.set_meta("urdf_loaded", true)

	# Create a dictionary to hold link nodes
	var link_nodes: Dictionary = {}

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

	# Build links first
	for link_name in link_data:
		var data = link_data[link_name]
		var link_node = _create_link_node(link_name, data)
		link_nodes[link_name] = link_node

	# Add root link to robot
	if root_link_name and link_nodes.has(root_link_name):
		root.add_child(link_nodes[root_link_name])

	# Build joints and hierarchy
	for j in joint_data:
		var joint_node = _create_joint_node(j, link_nodes)

		# Reparent child link under joint
		if link_nodes.has(j["child"]) and link_nodes.has(j["parent"]):
			var child_node = link_nodes[j["child"]]
			var parent_node = link_nodes[j["parent"]]

			# Remove child from robot root
			if child_node.get_parent() == root:
				root.remove_child(child_node)

			# Add joint to parent
			parent_node.add_child(joint_node)

			# Add child to joint
			joint_node.add_child(child_node)

	print("URDFToGodot: Built robot with ", link_data.size(), " links and ", joint_data.size(), " joints")
	return root


static func _create_link_node(link_name: String, data: Dictionary) -> Node3D:
	var node = Node3D.new()
	node.set_name(link_name)
	node.set_meta("mass", data.get("mass", 1.0))

	# Set origin transform
	var t = Transform3D()
	t = t.translated(data["origin_xyz"])
	var rpy = data["origin_rpy"]
	if rpy.length() > 0.001:
		var basis = Basis()
		basis = basis.rotated(Vector3(1, 0, 0), rpy.x)
		basis = basis.rotated(Vector3(0, 1, 0), rpy.y)
		basis = basis.rotated(Vector3(0, 0, 1), rpy.z)
		t.basis = basis
	node.transform = t

	# Create visual mesh
	if not data["visual_mesh_path"].is_empty():
		var mesh = _load_mesh(data["visual_mesh_path"])
		if mesh:
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.set_name("Visual")
			mesh_instance.mesh = mesh

			# Apply material color if no texture
			var mat = StandardMaterial3D.new()
			mat.albedo_color = data["material_color"]
			mesh_instance.material_override = mat

			node.add_child(mesh_instance)
		else:
			# Fallback to collision shape as visual
			var shape = _create_collision_shape(data)
			if shape:
				var mesh_instance = MeshInstance3D.new()
				mesh_instance.set_name("Visual")
				mesh_instance.mesh = shape
				var mat = StandardMaterial3D.new()
				mat.albedo_color = data["material_color"]
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh_instance.material_override = mat
				node.add_child(mesh_instance)
	else:
		# No mesh, create simple collision shape as visual
		var shape = _create_collision_shape(data)
		if shape:
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.set_name("Visual")
			mesh_instance.mesh = shape
			var mat = StandardMaterial3D.new()
			mat.albedo_color = data["material_color"]
			mesh_instance.material_override = mat
			node.add_child(mesh_instance)

	# Create collision shape
	var collision_shape = _create_collision_shape(data)
	if collision_shape:
		var collision_node = CollisionShape3D.new()
		collision_node.set_name("Collision")
		collision_node.shape = collision_shape
		node.add_child(collision_node)

	return node


static func _create_joint_node(j: Dictionary, link_nodes: Dictionary) -> Node3D:
	var joint_type = j["type"]

	# Create appropriate Godot node based on joint type
	var joint_node: Node3D

	match joint_type:
		"revolute", "continuous":
			# Use PinJoint3D for revolute/continuous joints (rotation around one axis)
			var pin = PinJoint3D.new()
			pin.set_name(j["name"])
			joint_node = pin
			# Note: Godot 4 PinJoint3D uses bias/damping/impulse_clamp, not limit params

		"prismatic":
			# Use SliderJoint3D for prismatic joints (linear motion)
			var slider = SliderJoint3D.new()
			slider.set_name(j["name"])
			joint_node = slider

		"fixed":
			# Use a simple Node3D for fixed joints
			var fixed = Node3D.new()
			fixed.set_name(j["name"])
			joint_node = fixed

		_:
			# Default to Node3D
			var generic = Node3D.new()
			generic.set_name(j["name"])
			joint_node = generic

	# Set origin transform
	var t = Transform3D()
	t = t.translated(j["origin_xyz"])
	var rpy = j["origin_rpy"]
	if rpy.length() > 0.001:
		var basis = Basis()
		basis = basis.rotated(Vector3(1, 0, 0), rpy.x)
		basis = basis.rotated(Vector3(0, 1, 0), rpy.y)
		basis = basis.rotated(Vector3(0, 0, 1), rpy.z)
		t.basis = basis
	joint_node.transform = t

	# Store joint limits as metadata for the UI to read
	var limit_lower = j.get("limit_lower", -INF)
	var limit_upper = j.get("limit_upper", INF)
	if limit_lower > -INF or limit_upper < INF:
		joint_node.set_meta("limit_lower", limit_lower)
		joint_node.set_meta("limit_upper", limit_upper)
		joint_node.set_meta("has_limits", true)

	return joint_node


static func _create_collision_shape(data: Dictionary) -> Shape3D:
	match data["collision_type"]:
		"box":
			var p = data["collision_params"]
			var shape = BoxShape3D.new()
			shape.size = p.get("size", Vector3(0.1, 0.1, 0.1))
			return shape
		"cylinder":
			var p = data["collision_params"]
			var shape = CylinderShape3D.new()
			shape.height = p.get("length", 1.0)
			shape.radius = p.get("radius", 0.05)
			return shape
		"sphere":
			var p = data["collision_params"]
			var shape = SphereShape3D.new()
			shape.radius = p.get("radius", 0.05)
			return shape
		_:
			# Default to small box
			var shape = BoxShape3D.new()
			shape.size = Vector3(0.1, 0.1, 0.1)
			return shape


static func _load_mesh(mesh_path: String) -> Mesh:
	if mesh_path.is_empty() or not FileAccess.file_exists(mesh_path):
		return null

	# Try to load as a mesh resource
	var loaded = load(mesh_path)
	if loaded and loaded is Mesh:
		return loaded
	elif loaded and loaded.can_instantiate():
		# It's a PackedScene
		var instance = loaded.instantiate()
		if instance is MeshInstance3D:
			return instance.mesh
		elif instance is Node3D:
			# Try to find mesh in children
			var mesh_instance = instance.find_child("Mesh*", false, false)
			if mesh_instance and mesh_instance is MeshInstance3D:
				return mesh_instance.mesh
	return null


static func _parse_xyz(xyz_str: String) -> Vector3:
	if xyz_str.is_empty():
		return Vector3.ZERO
	var parts = xyz_str.split(" ")
	if parts.size() < 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


static func _parse_rpy(rpy_str: String) -> Vector3:
	# URDF rpy is in radians
	if rpy_str.is_empty():
		return Vector3.ZERO
	var parts = rpy_str.split(" ")
	if parts.size() < 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


static func _resolve_mesh_path(uri: String) -> String:
	# Handle package:// URLs
	if uri.begins_with("package://"):
		var remainder = uri.substr(10)
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
		]
		for prefix in prefixes:
			if FileAccess.file_exists(prefix):
				return prefix

		# Check ROS_PACKAGE_PATH environment variable
		var ros_pkg_path = OS.get_environment("ROS_PACKAGE_PATH")
		if not ros_pkg_path.is_empty():
			for pkg_dir in ros_pkg_path.split(":"):
				var candidate = pkg_dir.trim_suffix("/") + file_path
				if FileAccess.file_exists(candidate):
					return candidate

		# Check AMENT_PREFIX_PATH (ROS2)
		var ament_path = OS.get_environment("AMENT_PREFIX_PATH")
		if not ament_path.is_empty():
			for ament_dir in ament_path.split(":"):
				var candidate = ament_dir.trim_suffix("/") + "/share/" + package_name + file_path
				if FileAccess.file_exists(candidate):
					return candidate

		# Check COLCON_PREFIX_PATH
		var colcon_path = OS.get_environment("COLCON_PREFIX_PATH")
		if not colcon_path.is_empty():
			for colcon_dir in colcon_path.split(":"):
				var candidate = colcon_dir.trim_suffix("/") + "/share/" + package_name + file_path
				if FileAccess.file_exists(candidate):
					return candidate

	return uri
