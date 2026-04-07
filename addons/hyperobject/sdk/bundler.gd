# bundler.gd
# ANS-104 Bundling helper for Arweave

class_name Bundler

var _items: Array = []
var _max_items: int = 500
var _max_size: int = 500 * 1024 * 1024  # 500 MiB


func add_item(data: PackedByteArray, tags: Dictionary, owner: String) -> Result:
	if _items.size() >= _max_items:
		return Result.err("Bundle is full (max %d items)" % _max_items)

	var item_size = data.size()
	var total_size = _get_total_size()
	if total_size + item_size > _max_size:
		return Result.err("Bundle would exceed max size")

	_items.append({"data": data, "tags": tags, "owner": owner})
	return Result.ok({"items_in_bundle": _items.size()})


func clear() -> void:
	_items.clear()


func get_item_count() -> int:
	return _items.size()


func is_full() -> bool:
	return _items.size() >= _max_items or _get_total_size() >= _max_size


func _get_total_size() -> int:
	var total = 0
	for item in _items:
		total += item["data"].size()
	return total


func finalize() -> Result:
	if _items.is_empty():
		return Result.err("Bundle is empty")

	var bundle = {"format": 2, "items": _items, "id": ""}
	clear()
	return Result.ok(bundle)
