# mjcf_to_godot.gd
# MuJoCo MJCF parser that creates Godot native scene tree.
# Same interface as URDFToGodot.parse(path) -> Node3D.

class_name MJCFToGodot
extends RefCounted


static func parse(mjcf_path: String) -> Node3D:
	if not FileAccess.file_exists(mjcf_path):
		push_error("MJCFToGodot: File not found: " + mjcf_path)
		return null

	var parser = XMLParser.new()
	var err = parser.open(mjcf_path)
	if err != OK:
		push_error("MJCFToGodot: Failed to open: " + mjcf_path)
		return null

	var defaults: Dictionary = {}
	var worldbody_element: Dictionary = {}
	var actuators: Array = []

	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var tag = parser.get_node_name()

		if tag == "default":
			_parse_default(parser, defaults)
		elif tag == "worldbody":
			worldbody_element = _parse_body(parser, defaults)
		elif tag == "actuator":
			_parse_actuator_section(parser, actuators)

	return _build_scene_tree(worldbody_element, actuators)


static func _parse_default(parser: XMLParser, out_defaults: Dictionary) -> void:
	var cls_name = parser.get_named_attribute_value_safe("class")
	var geoms: Dictionary = {}
	var joints: Dictionary = {}

	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "default":
			break
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var tag = parser.get_node_name()
		if tag == "geom":
			geoms = _parse_geom_attrs(parser)
		elif tag == "joint":
			joints = _parse_joint_attrs(parser)

	var entry: Dictionary = {}
	if not geoms.is_empty():
		entry["geom"] = geoms
	if not joints.is_empty():
		entry["joint"] = joints
	if cls_name.is_empty():
		cls_name = "__default__"
	out_defaults[cls_name] = entry


static func _parse_geom_attrs(parser: XMLParser) -> Dictionary:
	var attrs: Dictionary = {}
	var type_str = parser.get_named_attribute_value_safe("type")
	if not type_str.is_empty():
		attrs["type"] = type_str
	var size_str = parser.get_named_attribute_value_safe("size")
	if not size_str.is_empty():
		attrs["size"] = _parse_float_array(size_str)
	var rgba_str = parser.get_named_attribute_value_safe("rgba")
	if not rgba_str.is_empty():
		attrs["rgba"] = _parse_float_array(rgba_str)
	var mass_str = parser.get_named_attribute_value_safe("mass")
	if not mass_str.is_empty():
		attrs["mass"] = float(mass_str)
	return attrs


static func _parse_joint_attrs(parser: XMLParser) -> Dictionary:
	var attrs: Dictionary = {}
	var type_str = parser.get_named_attribute_value_safe("type")
	if not type_str.is_empty():
		attrs["type"] = type_str
	var axis_str = parser.get_named_attribute_value_safe("axis")
	if not axis_str.is_empty():
		attrs["axis"] = _parse_float_array(axis_str)
	var range_str = parser.get_named_attribute_value_safe("range")
	if not range_str.is_empty():
		attrs["range"] = _parse_float_array(range_str)
	return attrs


static func _parse_body(parser: XMLParser, defaults: Dictionary) -> Dictionary:
	var body: Dictionary = {
		"name": parser.get_named_attribute_value_safe("name"),
		"pos": _parse_float_array(parser.get_named_attribute_value_safe("pos")),
		"quat": _parse_float_array(parser.get_named_attribute_value_safe("quat")),
		"geoms": [],
		"joints": [],
		"inertial": {},
		"children": []
	}
	if body["pos"].is_empty():
		body["pos"] = [0.0, 0.0, 0.0]
	if body["quat"].is_empty():
		body["quat"] = [1.0, 0.0, 0.0, 0.0]

	var depth = 1
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "body":
			depth -= 1
			if depth == 0:
				break
			continue

		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue

		var tag = parser.get_node_name()
		var class_attr = parser.get_named_attribute_value_safe("class")

		if tag == "body":
			body["children"].append(_parse_body(parser, defaults))
			depth -= 1
		elif tag == "geom":
			var geom = _resolve_defaults("geom", _parse_geom_attrs(parser), class_attr, defaults)
			body["geoms"].append(geom)
		elif tag == "joint":
			var joint = _resolve_defaults("joint", _parse_joint_attrs(parser), class_attr, defaults)
			var joint_name = parser.get_named_attribute_value_safe("name")
			if not joint_name.is_empty():
				joint["name"] = joint_name
			body["joints"].append(joint)
		elif tag == "inertial":
			body["inertial"] = _parse_inertial(parser)
		elif tag == "site":
			var site_name = parser.get_named_attribute_value_safe("name")
			var site_pos = _parse_float_array(parser.get_named_attribute_value_safe("pos"))
			if not site_name.is_empty():
				body["site"] = {"name": site_name, "pos": site_pos}

	return body


static func _resolve_defaults(elem_type: String, attrs: Dictionary, cls_name: String, defaults: Dictionary) -> Dictionary:
	var resolved = attrs.duplicate()
	if not cls_name.is_empty() and defaults.has(cls_name):
		var cls = defaults[cls_name]
		if cls.has(elem_type):
			for key in cls[elem_type]:
				if not resolved.has(key):
					resolved[key] = cls[elem_type][key]
	if defaults.has("__default__"):
		var d = defaults["__default__"]
		if d.has(elem_type):
			for key in d[elem_type]:
				if not resolved.has(key):
					resolved[key] = d[elem_type][key]
	return resolved


static func _parse_inertial(parser: XMLParser) -> Dictionary:
	var inertial: Dictionary = {}
	var mass_str = parser.get_named_attribute_value_safe("mass")
	if not mass_str.is_empty():
		inertial["mass"] = float(mass_str)
	var pos_str = parser.get_named_attribute_value_safe("pos")
	if not pos_str.is_empty():
		inertial["pos"] = _parse_float_array(pos_str)
	var diag_str = parser.get_named_attribute_value_safe("diaginertia")
	if not diag_str.is_empty():
		inertial["diaginertia"] = _parse_float_array(diag_str)
	return inertial


static func _parse_actuator_section(parser: XMLParser, out_actuators: Array) -> void:
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "actuator":
			break
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() == "motor":
			out_actuators.append({
				"name": parser.get_named_attribute_value_safe("name"),
				"joint": parser.get_named_attribute_value_safe("joint"),
				"ctrlrange": _parse_float_array(parser.get_named_attribute_value_safe("ctrlrange"))
			})


static func _build_scene_tree(root_body: Dictionary, _actuators: Array) -> Node3D:
	var root = Node3D.new()
	root.set_name("Robot")
	root.set_meta("mjcf_loaded", true)
	root.set_meta("urdf_loaded", true)

	var body_node = _create_body_node(root_body)
	root.add_child(body_node)
	return root


static func _create_body_node(body: Dictionary) -> Node3D:
	var node = Node3D.new()
	var name = body.get("name", "body")
	node.set_name(name)

	# Set position from MJCF pos
	var pos = body.get("pos", [0.0, 0.0, 0.0])
	if pos.size() >= 3:
		node.position = Vector3(pos[0], pos[2], -pos[1])

	# Set rotation from MJCF quat (w,x,y,z format)
	var quat = body.get("quat", [1.0, 0.0, 0.0, 0.0])
	if quat.size() >= 4:
		node.quaternion = Quaternion(quat[1], quat[2], quat[3], quat[0])

	# Store inertial data
	var inertial = body.get("inertial", {})
	if inertial.has("mass"):
		node.set_meta("mass", inertial["mass"])

	# Create geoms
	for geom in body.get("geoms", []):
		_add_geom_to_node(node, geom)

	# Create joints and child bodies
	for joint_data in body.get("joints", []):
		var joint_node = _create_joint_from_mjcf(joint_data)
		node.add_child(joint_node)

		# First child body inherits the joint as its parent connector
		if not body["children"].is_empty():
			var child_body = body["children"].pop_front()
			var child_node = _create_body_node(child_body)
			joint_node.add_child(child_node)

	# Add remaining children directly
	for child_body in body.get("children", []):
		var child_node = _create_body_node(child_body)
		node.add_child(child_node)

	return node


static func _add_geom_to_node(parent: Node3D, geom: Dictionary) -> void:
	var geom_type = geom.get("type", "box")
	var size = geom.get("size", [0.05, 0.05, 0.05])
	var rgba = geom.get("rgba", [0.5, 0.5, 0.5, 1.0])

	var shape: Shape3D
	var mesh: Mesh

	match geom_type:
		"box":
			var box = BoxShape3D.new()
			box.size = Vector3(size[0] * 2, size[2] * 2, size[1] * 2)
			shape = box
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(size[0] * 2, size[2] * 2, size[1] * 2)
			mesh = box_mesh
		"cylinder":
			var cyl = CylinderShape3D.new()
			var r = size[0] if size.size() > 0 else 0.05
			var h = size[1] * 2 if size.size() > 1 else 0.1
			cyl.radius = r
			cyl.height = h
			shape = cyl
			var cyl_mesh = CylinderMesh.new()
			cyl_mesh.top_radius = r
			cyl_mesh.bottom_radius = r
			cyl_mesh.height = h
			mesh = cyl_mesh
		"sphere":
			var sphere = SphereShape3D.new()
			sphere.radius = size[0] if size.size() > 0 else 0.05
			shape = sphere
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = sphere.radius
			sphere_mesh.height = sphere.radius * 2
			mesh = sphere_mesh
		_:
			var box = BoxShape3D.new()
			box.size = Vector3(0.1, 0.1, 0.1)
			shape = box
			mesh = BoxMesh.new()

	# Collision shape
	var collision = CollisionShape3D.new()
	collision.shape = shape
	collision.set_name("Collision")
	parent.add_child(collision)

	# Visual mesh
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.set_name("Visual")
	var mat = StandardMaterial3D.new()
	var color = Color(rgba[0], rgba[1], rgba[2], rgba[3]) if rgba.size() >= 3 else Color.GRAY
	mat.albedo_color = color
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)


static func _create_joint_from_mjcf(data: Dictionary) -> Node3D:
	var joint_type = data.get("type", "hinge")
	var joint_name = data.get("name", "joint")

	match joint_type:
		"hinge", "ball":
			var pin = PinJoint3D.new()
			pin.set_name(joint_name)
			if data.has("range"):
				var r = data["range"]
				if r.size() >= 2:
					pin.set_meta("limit_lower", r[0])
					pin.set_meta("limit_upper", r[1])
					pin.set_meta("has_limits", true)
			return pin
		"slide":
			var slider = SliderJoint3D.new()
			slider.set_name(joint_name)
			if data.has("range"):
				var r = data["range"]
				if r.size() >= 2:
					slider.set_meta("limit_lower", r[0])
					slider.set_meta("limit_upper", r[1])
					slider.set_meta("has_limits", true)
			return slider
		_:
			var fixed = Node3D.new()
			fixed.set_name(joint_name)
			return fixed


static func _parse_float_array(s: String) -> Array:
	if s.is_empty():
		return []
	var parts = s.split(" ", false)
	var result: Array = []
	for p in parts:
		result.append(float(p))
	return result


static func _static_init():
	ModuleRegistry.register("import", "MJCFParser", preload("res://scripts/mjcf_to_godot.gd"))
