# nav_planner.gd
# Abstract interface for navigation planners
# All navigation backends (A*, Nav2) must implement this

class_name NavPlanner
extends CopernicusModule

## Signals

signal planning_started()
signal planning_progress(percent: float)
signal planning_finished(success: bool, path: Array)
signal planner_error(message: String)


## ===== Configuration =====

## Maximum iterations for iterative planners
var _max_iterations: int = 1000
## Tolerance in meters
var _tolerance: float = 0.1
## Robot radius for collision checking
var _robot_radius: float = 0.3
## Whether to smooth the path
var _smooth_path: bool = true


## ===== Core Methods =====

## Initialize the planner with optional configuration
func initialize(config: Dictionary) -> bool:
	_max_iterations = config.get("max_iterations", 1000)
	_tolerance = config.get("tolerance", 0.1)
	_robot_radius = config.get("robot_radius", 0.3)
	_smooth_path = config.get("smooth_path", true)
	return true


## Compute a path from start to goal
## start = starting position (Vector3)
## goal = goal position (Vector3)
## Returns Array of Vector3 waypoints, empty if no path found
func plan(start: Vector3, goal: Vector3) -> Array:
	push_error("NavPlanner.plan() must be implemented by subclass")
	return []


## Set the map/obstacle data
## map_data = {
##   "width": int,
##   "height": int,
##   "resolution": float,
##   "origin": Vector3,
##   "cells": Array of int (0=free, 1=obstacle)
## }
func set_map(map_data: Dictionary) -> void:
	push_error("NavPlanner.set_map() must be implemented by subclass")


## Clear the current map
func clear_map() -> void:
	pass


## Check if a position is valid (not in obstacle)
func is_valid_position(position: Vector3) -> bool:
	push_error("NavPlanner.is_valid_position() must be implemented by subclass")
	return false


## Get the last planned path (for visualization)
func get_last_path() -> Array:
	return []


## ===== Configuration Setters =====

func set_max_iterations(iterations: int) -> void:
	_max_iterations = max(1, iterations)


func set_tolerance(tolerance: float) -> void:
	_tolerance = max(0.0, tolerance)


func set_robot_radius(radius: float) -> void:
	_robot_radius = max(0.0, radius)


func set_smooth_path(smooth: bool) -> void:
	_smooth_path = smooth



	## ===== Module Identity =====

	static func get_module_category() -> String:
		return "nav"

	static func get_planner_name() -> String:
		return get_module_name()

	static func get_planner_description() -> String:
		return get_module_description()





## Check if this planner is available (dependencies installed, etc)
static func is_available() -> bool:
	return false


## Get requirements for this planner (for error messages)
static func get_requirements() -> String:
	return ""


## ===== Path Utilities =====

## Smooth a path using Catmull-Rom splines or similar
static func smooth_path(path: Array) -> Array:
	if path.size() < 3:
		return path

	var smoothed: Array = []
	smoothed.append(path[0])

	for i in range(1, path.size() - 1):
		var prev = path[i - 1]
		var curr = path[i]
		var next = path[i + 1]

		# Simple moving average of positions
		var avg = (prev + curr + next) / 3.0
		smoothed.append(avg)

	smoothed.append(path[path.size() - 1])
	return smoothed


## Calculate total path length
static func path_length(path: Array) -> float:
	if path.size() < 2:
		return 0.0

	var length = 0.0
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])

	return length


## Get path as array of positions for visualization
static func path_to_points(path: Array) -> PackedVector3Array:
	var points = PackedVector3Array()
	for pos in path:
		points.append(pos)
	return points


## Simplify path by removing redundant waypoints
static func simplify_path(path: Array, tolerance: float = 0.05) -> Array:
	if path.size() < 3:
		return path

	var simplified: Array = []
	simplified.append(path[0])

	var last_added = 0

	for i in range(1, path.size() - 1):
		var dir1 = (path[i] - path[last_added]).normalized()
		var dir2 = (path[i + 1] - path[i]).normalized()

		if dir1.distance_to(dir2) > tolerance:
			simplified.append(path[i])
			last_added = i

	simplified.append(path[path.size() - 1])
	return simplified
