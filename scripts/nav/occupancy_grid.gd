# occupancy_grid.gd
# Occupancy grid helper for navigation
# Converts scene obstacles to grid representation

class_name OccupancyGrid
extends RefCounted

## Grid properties
var _width: int = 0
var _height: int = 0
var _resolution: float = 0.1  # meters per cell
var _origin: Vector3 = Vector3.ZERO  # world position of grid origin (bottom-left)

## Grid data: 0 = free, 1 = obstacle, -1 = unknown
var _cells: Array = []

## World-to-grid transform
var _initialized: bool = false


## ===== Initialization =====

func _init() -> void:
	pass


func setup(width: int, height: int, resolution: float, origin: Vector3 = Vector3.ZERO) -> void:
	_width = width
	_height = height
	_resolution = resolution
	_origin = origin

	# Initialize grid with unknown (-1)
	_cells = []
	for y in range(_height):
		var row = []
		for x in range(_width):
			row.append(-1)
		_cells.append(row)

	_initialized = true


func from_scene(space_state: PhysicsDirectSpaceState3D, bounds_min: Vector3, bounds_max: Vector3, resolution: float = 0.1) -> void:
	_resolution = resolution
	_origin = bounds_min

	_width = int((bounds_max.x - bounds_min.x) / _resolution)
	_height = int((bounds_max.z - bounds_min.z) / _resolution)

	# Initialize free
	_cells = []
	for y in range(_height):
		var row = []
		for x in range(_width):
			row.append(0)
		_cells.append(row)

	# Raycast to find obstacles
	_scan_obstacles(space_state, bounds_min, bounds_max)


func _scan_obstacles(space_state: PhysicsDirectSpaceState3D, bounds_min: Vector3, bounds_max: Vector3) -> void:
	var step = _resolution * 2  # Sample at 2x resolution

	for x in range(0, _width):
		for y in range(0, _height):
			var world_x = _origin.x + x * _resolution
			var world_z = _origin.z + y * _resolution

			var ray_start = Vector3(world_x, bounds_max.y + 1.0, world_z)
			var ray_end = Vector3(world_x, bounds_min.y - 0.5, world_z)

			var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			query.collide_with_bodies = true
			query.collide_with_areas = false

			var result = space_state.intersect_ray(query)

			if result:
				# Hit something - mark as occupied
				_set_cell(x, y, 1)
			else:
				_set_cell(x, y, 0)


## ===== Grid Access =====

func get_cell(grid_x: int, grid_y: int) -> int:
	if not _is_in_bounds(grid_x, grid_y):
		return -1
	return _cells[grid_y][grid_x]


func set_cell(grid_x: int, grid_y: int, value: int) -> void:
	if _is_in_bounds(grid_x, grid_y):
		_cells[grid_y][grid_x] = value


func get_cell_world(world_pos: Vector3) -> int:
	var grid_pos = world_to_grid(world_pos)
	return get_cell(grid_pos.x, grid_pos.y)


func set_cell_world(world_pos: Vector3, value: int) -> void:
	var grid_pos = world_to_grid(world_pos)
	set_cell(grid_pos.x, grid_pos.y, value)


func mark_obstacle_world(world_pos: Vector3) -> void:
	set_cell_world(world_pos, 1)


func clear_obstacle_world(world_pos: Vector3) -> void:
	set_cell_world(world_pos, 0)


## ===== Coordinate Transforms =====

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var rel_x = world_pos.x - _origin.x
	var rel_z = world_pos.z - _origin.z
	return Vector2i(int(rel_x / _resolution), int(rel_z / _resolution))


func grid_to_world(grid_x: int, grid_y: int) -> Vector3:
	return Vector3(
		_origin.x + grid_x * _resolution,
		_world_height(grid_y),
		_origin.z + grid_y * _resolution
	)


func _world_height(grid_y: int) -> float:
	# For flat 2D navigation, Y is ground plane (0)
	return 0.0


func _is_in_bounds(grid_x: int, grid_y: int) -> bool:
	return grid_x >= 0 and grid_x < _width and grid_y >= 0 and grid_y < _height


## ===== Grid Information =====

func get_width() -> int:
	return _width


func get_height() -> int:
	return _height


func get_resolution() -> float:
	return _resolution


func get_origin() -> Vector3:
	return _origin


func is_initialized() -> bool:
	return _initialized


func get_bounds() -> Dictionary:
	return {
		"min": _origin,
		"max": Vector3(
			_origin.x + _width * _resolution,
			_origin.y,
			_origin.z + _height * _resolution
		)
	}


func get_cells() -> Array:
	return _cells.duplicate()


func get_free_cells() -> Array:
	var free: Array = []
	for y in range(_height):
		for x in range(_width):
			if _cells[y][x] == 0:
				free.append(Vector2i(x, y))
	return free


func get_obstacle_cells() -> Array:
	var obstacles: Array = []
	for y in range(_height):
		for x in range(_width):
			if _cells[y][x] == 1:
				obstacles.append(Vector2i(x, y))
	return obstacles


func get_cell_center(grid_x: int, grid_y: int) -> Vector3:
	return Vector3(
		_origin.x + (grid_x + 0.5) * _resolution,
		0.0,
		_origin.z + (grid_y + 0.5) * _resolution
	)


## ===== Grid Operations =====

func inflate_obstacles(radius_cells: int) -> void:
	"""Grow obstacles by specified radius"""
	if radius_cells <= 0:
		return

	var inflated = _cells.duplicate(true)

	for y in range(_height):
		for x in range(_width):
			if _cells[y][x] == 1:
				# Mark neighbors as obstacles
				for dx in range(-radius_cells, radius_cells + 1):
					for dz in range(-radius_cells, radius_cells + 1):
						var nx = x + dx
						var nz = y + dz
						if _is_in_bounds(nx, nz):
							inflated[nz][nx] = 1

	_cells = inflated


func clear() -> void:
	for y in range(_height):
		for x in range(_width):
			_cells[y][x] = 0


func reset_to_free() -> void:
	for y in range(_height):
		for x in range(_width):
			_cells[y][x] = 0


## ===== Serialization =====

func to_dictionary() -> Dictionary:
	return {
		"width": _width,
		"height": _height,
		"resolution": _resolution,
		"origin": _origin,
		"cells": _cells.duplicate()
	}


func from_dictionary(data: Dictionary) -> void:
	_width = data.get("width", 0)
	_height = data.get("height", 0)
	_resolution = data.get("resolution", 0.1)
	_origin = data.get("origin", Vector3.ZERO)
	_cells = data.get("cells", [])
	_initialized = _width > 0 and _height > 0


## ===== Visualization Helpers =====

func get_debug_cells() -> Array:
	"""Get cells formatted for visualization"""
	var debug: Array = []
	for y in range(_height):
		for x in range(_width):
			if _cells[y][x] == 1:
				debug.append({
					"position": get_cell_center(x, y),
					"size": Vector3(_resolution, 0.1, _resolution)
				})
	return debug


## ===== Static Helpers =====

static func create_from_world_size(world_width: float, world_height: float, resolution: float) -> OccupancyGrid:
	var grid = OccupancyGrid.new()
	grid.setup(
		int(world_width / resolution),
		int(world_height / resolution),
		resolution
	)
	return grid


static func create_square(center: Vector3, size: float, resolution: float) -> OccupancyGrid:
	var half = size / 2.0
	var grid = OccupancyGrid.new()
	grid.setup(
		int(size / resolution),
		int(size / resolution),
		resolution,
		Vector3(center.x - half, 0, center.z - half)
	)
	return grid
