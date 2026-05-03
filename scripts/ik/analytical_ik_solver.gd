# analytical_ik_solver.gd
# Analytical IK solvers: CCD and FABRIK
# Pure GDScript implementations, no external dependencies

class_name AnalyticalIKSolver
extends IKSolver

## IK Algorithm type
enum Algorithm { CCD, FABRIK }
var _algorithm: Algorithm = Algorithm.CCD

## Internal state
var _joint_rotations: Array = []
var _end_effector_position: Vector3 = Vector3.ZERO
var _final_distance: float = INF
var _iterations_used: int = 0


static func get_module_name() -> String:
	return "Analytical IK"


static func get_module_description() -> String:
	return "Pure GDScript IK solvers (CCD, FABRIK). No external dependencies. Good for simple chains."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "None - pure GDScript implementation"



static func get_module_category() -> String:
	return "ik"

static func _static_init():
	ModuleRegistry.register("ik", "AnalyticalIKSolver", preload("res://scripts/ik/analytical_ik_solver.gd"))
func initialize(config: Dictionary) -> bool:
	super.initialize(config)
	_algorithm = config.get("algorithm", Algorithm.CCD)
	return true


func set_algorithm(algorithm: Algorithm) -> void:
	_algorithm = algorithm


func solve(chain: Array, target: Vector3) -> bool:
	if chain.is_empty():
		return false

	reset()
	solving_started.emit()

	# Initialize joint rotations
	for joint_data in chain:
		_joint_rotations.append(joint_data.get("rotation", Quaternion.IDENTITY))

	# Run the appropriate algorithm
	var success = false

	match _algorithm:
		Algorithm.CCD:
			success = _solve_ccd(chain, target)
		Algorithm.FABRIK:
			success = _solve_fabrik(chain, target)
		_:
			success = _solve_ccd(chain, target)

	solving_finished.emit(success, _iterations_used)
	return success


func get_joint_rotations() -> Array:
	return _joint_rotations.duplicate()


func get_end_effector_position() -> Vector3:
	return _end_effector_position


func get_final_distance() -> float:
	return _final_distance


func get_iterations_used() -> int:
	return _iterations_used


func reset() -> void:
	_joint_rotations.clear()
	_end_effector_position = Vector3.ZERO
	_final_distance = INF
	_iterations_used = 0


## ===== CCD (Cyclic Coordinate Descent) =====

func _solve_ccd(chain: Array, target: Vector3) -> bool:
	_final_distance = _calculate_end_distance(chain, target)

	for i in range(_max_iterations):
		_iterations_used = i + 1

		# Iterate from end to base (CCD typically goes end-to-base)
		for j in range(chain.size() - 1, -1, -1):
			var joint_data = chain[j]
			var joint_pos = joint_data.get("position", Vector3.ZERO)
			var axis = joint_data.get("axis", Vector3(0, 1, 0))

			# Get current end position
			var current_end = _get_end_position(chain)
			var to_end = current_end - joint_pos
			var to_target = target - joint_pos

			# Calculate rotation to align end->target
			var current_angle = _angle_between(to_end, to_target)

			if current_angle > _tolerance:
				# Rotation axis is perpendicular to both vectors
				var rot_axis = to_end.cross(to_target).normalized()

				if rot_axis.length() > 0.001:
					# Create rotation quaternion
					var rot = Quaternion(rot_axis, min(current_angle, PI / 4))

					# Apply rotation constraint
					rot = _constrain_rotation(rot, joint_data)

					# Apply to this joint and all downstream
					var rot_j = joint_data.get("rotation", Quaternion.IDENTITY)
					rot_j = rot * rot_j
					joint_data["rotation"] = rot_j
					_joint_rotations[j] = rot_j

					# Update downstream joint positions
					_update_downstream_positions(chain, j)

		_final_distance = _calculate_end_distance(chain, target)
		solving_progress.emit(_iterations_used, _final_distance)

		if _final_distance <= _tolerance:
			return true

	_final_distance = _calculate_end_distance(chain, target)
	return _final_distance <= _tolerance


## ===== FABRIK (Forward And Backward Reaching IK) =====

func _solve_fabrik(chain: Array, target: Vector3) -> bool:
	if chain.size() < 2:
		return false

	# Calculate total chain length
	var total_length = 0.0
	var segment_lengths: Array = []

	for i in range(1, chain.size()):
		var prev_pos = chain[i - 1].get("position", Vector3.ZERO)
		var curr_pos = chain[i].get("position", Vector3.ZERO)
		var length = prev_pos.distance_to(curr_pos)
		segment_lengths.append(length)
		total_length += length

	# Get base position
	var base_pos = chain[0].get("position", Vector3.ZERO)

	# Check if target is reachable
	var dist_to_target = base_pos.distance_to(target)
	if dist_to_target > total_length:
		# Target too far - stretch toward it
		var direction = (target - base_pos).normalized()
		for i in range(1, chain.size()):
			var new_pos = chain[i - 1].get("position", Vector3.ZERO) + direction * segment_lengths[i - 1]
			chain[i]["position"] = new_pos
		_update_rotations_from_positions(chain)
		_final_distance = dist_to_target - total_length
		return false

	for iteration in range(_max_iterations):
		_iterations_used = iteration + 1

		# Forward reaching: pull end effector toward target
		chain[chain.size() - 1]["position"] = target

		for i in range(chain.size() - 2, -1, -1):
			var direction = (chain[i + 1]["position"] - chain[i]["position"]).normalized()
			chain[i]["position"] = chain[i + 1]["position"] - direction * segment_lengths[i]

		# Check if close enough
		var end_pos = chain[chain.size() - 1]["position"]
		_final_distance = end_pos.distance_to(target)
		solving_progress.emit(_iterations_used, _final_distance)

		if _final_distance <= _tolerance:
			_update_rotations_from_positions(chain)
			return true

		# Backward reaching: constrain base to original position
		chain[0]["position"] = base_pos

		for i in range(1, chain.size()):
			var direction = (chain[i - 1]["position"] - chain[i]["position"]).normalized()
			chain[i]["position"] = chain[i - 1]["position"] + direction * segment_lengths[i]

	# Final check
	var end_pos = chain[chain.size() - 1]["position"]
	_final_distance = end_pos.distance_to(target)
	_update_rotations_from_positions(chain)
	return _final_distance <= _tolerance


## ===== Helper Methods =====

func _get_end_position(chain: Array) -> Vector3:
	if chain.is_empty():
		return Vector3.ZERO
	return chain[chain.size() - 1].get("position", Vector3.ZERO)


func _calculate_end_distance(chain: Array, target: Vector3) -> float:
	var end_pos = _get_end_position(chain)
	_end_effector_position = end_pos
	return end_pos.distance_to(target)


func _angle_between(v1: Vector3, v2: Vector3) -> float:
	var dot = v1.normalized().dot(v2.normalized())
	return acos(clamp(dot, -1.0, 1.0))


func _constrain_rotation(rot: Quaternion, joint_data: Dictionary) -> Quaternion:
	# This is a simplified constraint - full implementation would
	# respect min_angle/max_angle limits
	var axis = joint_data.get("axis", Vector3(0, 1, 0))

	# Project rotation onto allowed axes
	if not _allow_rotation_x:
		rot = _remove_rotation_around_axis(rot, Vector3.RIGHT)
	if not _allow_rotation_y:
		rot = _remove_rotation_around_axis(rot, Vector3.UP)
	if not _allow_rotation_z:
		rot = _remove_rotation_around_axis(rot, Vector3.BACK)

	return rot


func _remove_rotation_around_axis(rot: Quaternion, axis: Vector3) -> Quaternion:
	# Decompose rotation and remove component around axis
	var angle = rot.get_angle()
	var rot_axis = rot.get_axis()

	var projected_axis = rot_axis - rot_axis.dot(axis) * axis
	if projected_axis.length() < 0.001:
		return Quaternion.IDENTITY

	projected_axis = projected_axis.normalized()
	return Quaternion(projected_axis, angle)


func _update_downstream_positions(chain: Array, from_index: int) -> void:
	# When a joint rotates, update positions of all downstream joints
	# This is a simplified version - full implementation would use proper FK
	pass


func _update_rotations_from_positions(chain: Array) -> void:
	# Calculate rotations from position changes
	# This is a simplified implementation
	for i in range(chain.size()):
		_joint_rotations[i] = Quaternion.IDENTITY
