# omni_connector.gd
# Abstract base interface for Omniverse connectors
# Provides common functionality for all Omniverse connection types

class_name OmniConnector
extends RefCounted


## ===== Signals =====

signal connected()
signal disconnected()
signal scene_synced()
signal error_occurred(error: String)
signal connection_status_changed(status: String)


## ===== Connection State =====

var _connected: bool = false
var _connector_type: String = "Base"
var _uri: String = ""
var _last_sync_time: float = 0.0


## ===== Configuration =====

var _sync_interval: float = 0.1  # Seconds between syncs
var _auto_sync: bool = false
var _sync_materials: bool = true
var _sync_transforms: bool = true
var _sync_meshes: bool = true


## ===== Virtual Methods (Override in Subclasses) =====

## Get connector name
static func get_connector_name() -> String:
	return "OmniConnector"


## Get connector description
static func get_connector_description() -> String:
	return "Base Omniverse connector interface"


## Check if this connector is available (dependencies met)
static func is_available() -> bool:
	return false


## Get requirements text
static func get_requirements() -> String:
	return "Unknown requirements"


## ===== Connection Management =====

## Connect to Omniverse
func connect(uri: String) -> bool:
	push_error("OmniConnector.connect() must be implemented by subclass")
	return false


## Disconnect from Omniverse
func disconnect() -> void:
	push_error("OmniConnector.disconnect() must be implemented by subclass")


## Check connection status
func is_connected() -> bool:
	return _connected


## ===== Scene Synchronization =====

## Sync entire Godot scene to Omniverse
func sync_scene(scene: Node3D) -> bool:
	push_error("OmniConnector.sync_scene() must be implemented by subclass")
	return false


## Sync a single node to Omniverse
func sync_node(node: Node3D) -> bool:
	push_error("OmniConnector.sync_node() must be implemented by subclass")
	return false


## Receive updates from Omniverse
func receive_updates() -> void:
	pass  # Override in subclass for polling


## ===== Transform Sync =====

## Send transform update for a node
func send_transform(node_path: String, transform: Transform3D) -> bool:
	push_error("OmniConnector.send_transform() must be implemented by subclass")
	return false


## ===== Material Sync =====

## Send material update
func send_material(material_path: String, material_data: Dictionary) -> bool:
	if not _sync_materials:
		return true
	push_error("OmniConnector.send_material() must be implemented by subclass")
	return false


## ===== Mesh Sync =====

## Send mesh geometry update
func send_mesh(mesh_path: String, mesh_data: Dictionary) -> bool:
	if not _sync_meshes:
		return true
	push_error("OmniConnector.send_mesh() must be implemented by subclass")
	return false


## ===== Configuration =====

func configure(config: Dictionary) -> void:
	_uri = config.get("uri", "")
	_sync_interval = config.get("sync_interval", 0.1)
	_auto_sync = config.get("auto_sync", false)
	_sync_materials = config.get("sync_materials", true)
	_sync_transforms = config.get("sync_transforms", true)
	_sync_meshes = config.get("sync_meshes", true)


## ===== Utility =====

func get_connector_type() -> String:
	return _connector_type


func get_uri() -> String:
	return _uri


func get_last_sync_time() -> float:
	return _last_sync_time


## ===== Status =====

func get_status() -> Dictionary:
	return {
		"connected": _connected,
		"type": _connector_type,
		"uri": _uri,
		"last_sync": _last_sync_time,
		"auto_sync": _auto_sync
	}


## ===== Default Implementation =====

func _notification_callback(notification: String, data: Dictionary) -> void:
	match notification:
		"connection_changed":
			_connected = data.get("connected", false)
			if _connected:
				emit_signal("connected")
			else:
				emit_signal("disconnected")
		"sync_complete":
			_last_sync_time = Time.get_ticks_msec() / 1000.0
			emit_signal("scene_synced")
		"error":
			emit_signal("error_occurred", data.get("message", "Unknown error"))


## ===== Connectable Node Tracking =====

var _tracked_nodes: Dictionary = {}


func track_node(node: Node3D) -> void:
	if node:
		_tracked_nodes[node.get_path()] = node


func untrack_node(node: Node3D) -> void:
	if node:
		_tracked_nodes.erase(node.get_path())


func get_tracked_nodes() -> Array:
	return _tracked_nodes.values()


## ===== Export/Import Helpers =====

func godot_transform_to_list(transform: Transform3D) -> Array:
	var basis = transform.basis
	var origin = transform.origin
	return [
		basis.x.x, basis.y.x, basis.z.x, 0,
		basis.x.y, basis.y.y, basis.z.y, 0,
		basis.x.z, basis.y.z, basis.z.z, 0,
		origin.x, origin.y, origin.z, 1
	]


func list_to_godot_transform(data: Array) -> Transform3D:
	if data.size() < 16:
		return Transform3D.IDENTITY

	var basis = Basis(
		Vector3(data[0], data[1], data[2]),
		Vector3(data[4], data[5], data[6]),
		Vector3(data[8], data[9], data[10])
	)
	var origin = Vector3(data[12], data[13], data[14])
	return Transform3D(basis, origin)