# hyperobjects.gd
# AO Hyperobjects - Asset framework for AO processes

class_name Hyperobject

enum Type { GENERIC, AVATAR, ITEM, WORLD }
enum State { ACTIVE, INACTIVE, BURNED }

var _id: String
var _name: String
var _type: Type
var _state: State = State.ACTIVE
var _owner: String
var _creator: String
var _metadata: Dictionary = {}
var _asset_tx_id: String = ""
var _process_id: String = ""


func _init(name: String, hyperobject_type: Type = Type.GENERIC, process_id: String = "") -> void:
	_name = name
	_type = hyperobject_type
	_process_id = process_id


static func create(name: String, hyperobject_type: Type = Type.GENERIC) -> Hyperobject:
	return Hyperobject.new(name, hyperobject_type)


static func from_info(name: String, info: Dictionary) -> Hyperobject:
	var obj = Hyperobject.new(name, Type.GENERIC, info.get("process_id", ""))
	obj._metadata = info
	obj._owner = info.get("owner", "")
	obj._creator = info.get("creator", "")
	return obj


func get_id() -> String:
	return _id


func get_name() -> String:
	return _name


func get_type() -> Type:
	return _type


func get_type_string() -> String:
	match _type:
		Type.AVATAR: return "avatar"
		Type.ITEM: return "item"
		Type.WORLD: return "world"
		_: return "generic"


func get_state() -> State:
	return _state


func get_owner() -> String:
	return _owner


func get_creator() -> String:
	return _creator


func get_metadata() -> Dictionary:
	return _metadata


func get_asset_tx_id() -> String:
	return _asset_tx_id


func get_process_id() -> String:
	return _process_id


func set_owner(owner: String) -> void:
	_owner = owner


func set_metadata(metadata: Dictionary) -> void:
	_metadata = metadata


func set_asset_tx_id(tx_id: String) -> void:
	_asset_tx_id = tx_id


func set_process_id(pid: String) -> void:
	_process_id = pid


func is_active() -> bool:
	return _state == State.ACTIVE


func to_dictionary() -> Dictionary:
	return {
		"id": _id,
		"name": _name,
		"type": get_type_string(),
		"state": _state,
		"owner": _owner,
		"creator": _creator,
		"metadata": _metadata,
		"asset_tx_id": _asset_tx_id,
		"process_id": _process_id
	}


class_name HyperobjectManager

var _hyperobjects: Dictionary = {}


func register(hyperobject: Hyperobject) -> void:
	_hyperobjects[hyperobject.get_id()] = hyperobject


func unregister(id: String) -> void:
	_hyperobjects.erase(id)


func get(id: String) -> Hyperobject:
	return _hyperobjects.get(id)


func get_all() -> Array:
	return _hyperobjects.values()


func get_by_owner(owner: String) -> Array:
	var result: Array = []
	for h in _hyperobjects.values():
		if h.get_owner() == owner:
			result.append(h)
	return result


func get_by_type(type: Hyperobject.Type) -> Array:
	var result: Array = []
	for h in _hyperobjects.values():
		if h.get_type() == type:
			result.append(h)
	return result
