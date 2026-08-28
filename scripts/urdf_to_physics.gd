# urdf_to_physics.gd
# Converts URDF scene tree output into physics bodies managed by a PhysicsBackend.
# Walk the robot tree, extract link/collision data, create bodies and joints.

class_name URDFToPhysics
extends RefCounted


static func create_physics_bodies(robot_root: Node3D, backend: PhysicsBackend, config: Dictionary = {}) -> bool:
	var link_map: Dictionary = {}  # link_name -> {"node": Node3D, "collision": CollisionShape3D, "mass": float}
	var joint_list: Array = []

	# Phase 1: Recursively collect every link (a link has a collision shape child).
	for node in robot_root.find_children("*", "Node3D", true, false):
		var collision = _find_collision_shape(node)
		if collision:
			link_map[node.name] = {"node": node, "collision": collision, "mass": float(node.get_meta("mass", 1.0))}

	# Collect every physics joint recursively.
	for node in robot_root.find_children("*", "Joint3D", true, false):
		var joint = node as Joint3D
		var parent_name = joint.get_parent().name if joint.get_parent() else ""
		var child_body = ""
		for c in joint.get_children():
			child_body = c.name
			break
		var jtype = "revolute"
		if joint is SliderJoint3D:
			jtype = "prismatic"
		elif not (joint is PinJoint3D):
			jtype = "fixed"
		joint_list.append({
			"name": joint.name,
			"type": jtype,
			"parent": parent_name,
			"child": child_body,
			"axis": Vector3(0, 1, 0),
			"anchor_parent": joint.position,
			"anchor_child": Vector3.ZERO,
			"limits": _get_joint_limits(joint)
		})

	# Phase 2: Create physics bodies for each link
	for link_name in link_map:
		var info = link_map[link_name]
		var body_config = _build_body_config(info)
		if not backend.create_rigid_body(link_name, body_config):
			push_error("URDFToPhysics: Failed to create body for " + link_name)
			return false

	# Phase 3: Create joints between bodies
	for j in joint_list:
		var joint_config = _build_joint_config(j)
		if not backend.create_joint(j["name"], joint_config):
			push_error("URDFToPhysics: Failed to create joint " + j["name"])

	return true


static func _find_collision_shape(node: Node3D) -> CollisionShape3D:
	for child in node.get_children():
		if child is CollisionShape3D:
			return child
		if child is StaticBody3D:
			for sub in child.get_children():
				if sub is CollisionShape3D:
					return sub
	return null


static func _register_joints(node: Node3D, parent_name: String, root: Node3D, out_joints: Array) -> void:
	for child in node.get_children():
		var child_name = child.name
		if child is PinJoint3D:
			var joint = child as PinJoint3D
			var child_body = ""
			for c in joint.get_children():
				child_body = c.name
				break
			out_joints.append({
				"name": child_name,
				"type": "revolute",
				"parent": parent_name,
				"child": child_body,
				"axis": Vector3(0, 1, 0),
				"anchor_parent": joint.position,
				"anchor_child": Vector3.ZERO,
				"limits": _get_joint_limits(joint)
			})
		elif child is SliderJoint3D:
			var joint = child as SliderJoint3D
			var child_body = ""
			for c in joint.get_children():
				child_body = c.name
				break
			out_joints.append({
				"name": child_name,
				"type": "prismatic",
				"parent": parent_name,
				"child": child_body,
				"axis": Vector3(1, 0, 0),
				"anchor_parent": joint.position,
				"anchor_child": Vector3.ZERO,
				"limits": _get_joint_limits(joint)
			})


static func _get_joint_limits(joint: Node3D) -> Dictionary:
	if joint.has_meta("has_limits") and joint.get_meta("has_limits"):
		return {
			"lower": joint.get_meta("limit_lower", -INF),
			"upper": joint.get_meta("limit_upper", INF)
		}
	return {}


static func _build_body_config(info: Dictionary) -> Dictionary:
	var node: Node3D = info["node"]
	var collision: CollisionShape3D = info["collision"]
	var config: Dictionary = {
		"position": node.position,
		"rotation": Quaternion.from_euler(node.rotation),
		"mass": info.get("mass", 1.0)
	}

	if collision:
		var shape = collision.shape
		if shape is BoxShape3D:
			config["type"] = "box"
			config["size"] = shape.size
		elif shape is CylinderShape3D:
			config["type"] = "cylinder"
			config["radius"] = shape.radius
			config["length"] = shape.height
		elif shape is SphereShape3D:
			config["type"] = "sphere"
			config["radius"] = shape.radius
		else:
			config["type"] = "box"
			config["size"] = Vector3(0.1, 0.1, 0.1)

	return config


static func _build_joint_config(j: Dictionary) -> Dictionary:
	var config: Dictionary = {
		"type": j.get("type", "revolute"),
		"parent": j.get("parent", ""),
		"child": j.get("child", ""),
		"anchor_parent": j.get("anchor_parent", Vector3.ZERO),
		"anchor_child": j.get("anchor_child", Vector3.ZERO),
		"axis": j.get("axis", Vector3(0, 1, 0))
	}
	var limits = j.get("limits", {})
	if not limits.is_empty():
		config["limits"] = limits
	return config
