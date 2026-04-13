# astar_grid_planner.gd
# A* Grid-based path planner
# Pure GDScript implementation, no external dependencies

class_name AStarGridPlanner
extends NavPlanner

# Ensure NavPlanner is loaded first
const _NavPlannerRef = preload("res://scripts/nav/nav_planner.gd")

## Grid map data
var _grid_width: int = 0
var _grid_height: int = 0
var _resolution: float = 0.1
var _origin: Vector3 = Vector3.ZERO
var _cells: Array = []  # 2D array [y][x] = 0 (free) or 1 (obstacle)

## Last planned path
var _last_path: Array = []

## Use 8-connectivity (diagonal movement)
var _use_diagonals: bool = true


static func get_planner_name() -> String:
	return "A* Grid Planner"


static func get_planner_description() -> String:
	return "Pure GDScript A* path planner. Works on grid maps. No external dependencies."


static func is_available() -> bool:
	return true


static func get_requirements() -> String:
	return "None - pure GDScript implementation"


func initialize(config: Dictionary) -> bool:
	super.initialize(config)
	_use_diagonals = config.get("use_diagonals", true)
	return true


func set_map(map_data: Dictionary) -> void:
	_grid_width = map_data.get("width", 0)
	_grid_height = map_data.get("height", 0)
	_resolution = map_data.get("resolution", 0.1)
	_origin = map_data.get("origin", Vector3.ZERO)
	_cells = map_data.get("cells", [])

	if _cells.is_empty() and _grid_width > 0 and _grid_height > 0:
		# Initialize empty grid
		_cells = []
		for y in range(_grid_height):
			var row = []
			for x in range(_grid_width):
				row.append(0)
			_cells.append(row)


func clear_map() -> void:
	_grid_width = 0
	_grid_height = 0
	_cells.clear()
	_last_path.clear()


func is_valid_position(position: Vector3) -> bool:
	var grid_pos = _world_to_grid(position)
	return _is_in_bounds(grid_pos.x, grid_pos.y) and _get_cell(grid_pos.x, grid_pos.y) == 0


func get_last_path() -> Array:
	return _last_path.duplicate()


func plan(start: Vector3, goal: Vector3) -> Array:
	if _grid_width == 0 or _grid_height == 0:
		push_error("AStarGridPlanner: No map set")
		planner_error.emit("No map set")
		return []

	planning_started.emit()

	var start_grid = _world_to_grid(start)
	var goal_grid = _world_to_grid(goal)

	# Snap to grid
	start_grid = _snap_to_grid(start_grid)
	goal_grid = _snap_to_grid(goal_grid)

	# Check if start and goal are valid
	if not _is_in_bounds(start_grid.x, start_grid.y) or _get_cell(start_grid.x, start_grid.y) == 1:
		planning_finished.emit(false, [])
		return []

	if not _is_in_bounds(goal_grid.x, goal_grid.y) or _get_cell(goal_grid.x, goal_grid.y) == 1:
		planning_finished.emit(false, [])
		return []

	# A* implementation
	var open_set: Array = [start_grid]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	var start_key = _grid_key(start_grid.x, start_grid.y)
	g_score[start_key] = 0.0
	f_score[start_key] = _heuristic(start_grid, goal_grid)

	var iterations = 0

	while not open_set.is_empty() and iterations < _max_iterations:
		iterations += 1

		if iterations % 100 == 0:
			planning_progress.emit(float(iterations) / float(_max_iterations))

		# Find node in open_set with lowest f_score
		var current = _get_lowest_f_score(open_set, f_score)
		var current_key = _grid_key(current.x, current.y)

		# Check if we reached the goal
		if current.x == goal_grid.x and current.y == goal_grid.y:
			var path = _reconstruct_path(came_from, current)
			_last_path = path

			if _smooth_path:
				path = smooth_path(path)

			planning_finished.emit(true, path)
			return path

		# Move current from open_set to closed_set
		open_set.erase(current)

		# Check neighbors
		var neighbors = _get_neighbors(current)

		for neighbor in neighbors:
			var neighbor_key = _grid_key(neighbor.x, neighbor.y)

			# Skip if in closed set or obstacle
			if _get_cell(neighbor.x, neighbor.y) == 1:
				continue

			# Calculate tentative g_score
			var move_cost = _get_move_cost(current, neighbor)
			var tentative_g = g_score.get(current_key, INF) + move_cost

			# If this path is better
			if tentative_g < g_score.get(neighbor_key, INF):
				came_from[neighbor_key] = current
				g_score[neighbor_key] = tentative_g
				f_score[neighbor_key] = tentative_g + _heuristic(neighbor, goal_grid)

				if not open_set.has(neighbor):
					open_set.append(neighbor)

	planning_finished.emit(false, [])
	return []


## ===== Grid Helpers =====

func _world_to_grid(world_pos: Vector3) -> Vector2i:
	var rel = world_pos - _origin
	return Vector2i(
		int(rel.x / _resolution),
		int(rel.z / _resolution)
	)


func _grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		_origin.x + grid_pos.x * _resolution,
		_world_to_grid_y(grid_pos.y),
		_origin.z + grid_pos.y * _resolution
	)


func _world_to_grid_y(y_world: float) -> float:
	# For 2D grid navigation, Y is typically 0 (ground plane)
	return 0.0


func _snap_to_grid(pos: Vector2i) -> Vector2i:
	return Vector2i(clampi(pos.x, 0, _grid_width - 1), clampi(pos.y, 0, _grid_height - 1))


func _is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < _grid_width and y >= 0 and y < _grid_height


func _get_cell(x: int, y: int) -> int:
	if not _is_in_bounds(x, y):
		return 1  # Out of bounds = obstacle
	if _cells.is_empty() or y >= _cells.size() or _cells[y].size() == 0:
		return 0
	return _cells[y][x]


func _set_cell(x: int, y: int, value: int) -> void:
	if _is_in_bounds(x, y) and not _cells.is_empty() and y < _cells.size():
		_cells[y][x] = value


func _grid_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func _parse_key(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


## ===== A* Helpers =====

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	# Manhattan distance (or Euclidean for 8-connectivity)
	if _use_diagonals:
		# Euclidean for diagonal movement
		return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
	else:
		# Manhattan for 4-connectivity
		return abs(a.x - b.x) + abs(a.y - b.y)


func _get_neighbors(pos: Vector2i) -> Array:
	var neighbors: Array = []

	# 4 or 8 connectivity
	var directions: Array
	if _use_diagonals:
		directions = [
			Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),  # 4 cardinal
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)  # 4 diagonal
		]
	else:
		directions = [
			Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
		]

	for d in directions:
		var nx = pos.x + d.x
		var ny = pos.y + d.y

		if _is_in_bounds(nx, ny) and _get_cell(nx, ny) == 0:
			neighbors.append(Vector2i(nx, ny))

	return neighbors


func _get_move_cost(from: Vector2i, to: Vector2i) -> float:
	# Diagonal movement costs sqrt(2)
	if from.x != to.x and from.y != to.y:
		return sqrt(2.0) * _resolution
	return _resolution


func _get_lowest_f_score(open_set: Array, f_score: Dictionary) -> Vector2i:
	var best: Vector2i = open_set[0]
	var best_f = f_score.get(_grid_key(best.x, best.y), INF)

	for pos in open_set:
		var key = _grid_key(pos.x, pos.y)
		var f = f_score.get(key, INF)
		if f < best_f:
			best = pos
			best_f = f

	return best


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path: Array = []

	# Convert grid positions to world positions
	var pos = current
	while came_from.has(_grid_key(pos.x, pos.y)):
		path.push_front(_grid_to_world(pos))
		pos = came_from[_grid_key(pos.x, pos.y)]

	# Add start position
	path.push_front(_grid_to_world(pos))

	return path


## ===== Map Editing =====

func mark_obstacle(world_pos: Vector3) -> void:
	var grid_pos = _world_to_grid(world_pos)
	_set_cell(grid_pos.x, grid_pos.y, 1)


func clear_obstacle(world_pos: Vector3) -> void:
	var grid_pos = _world_to_grid(world_pos)
	_set_cell(grid_pos.x, grid_pos.y, 0)


func mark_area(center: Vector3, radius: float) -> void:
	var center_grid = _world_to_grid(center)
	var radius_cells = int(radius / _resolution)

	for dx in range(-radius_cells, radius_cells + 1):
		for dy in range(-radius_cells, radius_cells + 1):
			var wx = center_grid.x + dx
			var wy = center_grid.y + dy
			if _is_in_bounds(wx, wy):
				var world_x = _origin.x + wx * _resolution
				var world_z = _origin.z + wy * _resolution
				var dist = sqrt(pow(world_x - center.x, 2) + pow(world_z - center.z, 2))
				if dist <= radius:
					_set_cell(wx, wy, 1)


func get_occupancy_grid() -> Array:
	return _cells.duplicate()


func get_grid_info() -> Dictionary:
	return {
		"width": _grid_width,
		"height": _grid_height,
		"resolution": _resolution,
		"origin": _origin
	}
