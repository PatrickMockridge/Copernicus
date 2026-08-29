# command_registry.gd
# Autoload singleton — the command palette's backing store.
# Modules (and the shell) register commands; the palette queries + runs them.

extends Node

var _commands: Array = []


func register(cmd: Dictionary) -> void:
	# cmd: {id, label, category, description, keywords, handler: Callable}
	if not cmd.has("id") or not cmd.has("handler"):
		push_error("CommandRegistry.register: command needs 'id' and 'handler'")
		return
	_unregister(cmd["id"])
	_commands.append(cmd)


func _unregister(id: String) -> void:
	for i in range(_commands.size() - 1, -1, -1):
		if _commands[i].get("id", "") == id:
			_commands.remove_at(i)


func query(text: String) -> Array:
	var q := text.strip_edges().to_lower()
	if q.is_empty():
		return _commands.duplicate()
	var scored: Array = []
	for cmd in _commands:
		var s := _score(cmd, q)
		if s >= 0:
			scored.append({"cmd": cmd, "score": s})
	scored.sort_custom(func(a, b) -> bool: return a["score"] < b["score"])
	var out: Array = []
	for r in scored:
		out.append(r["cmd"])
	return out


func _score(cmd: Dictionary, q: String) -> int:
	var label: String = str(cmd.get("label", "")).to_lower()
	if q in label:
		return label.find(q)
	var cat: String = str(cmd.get("category", "")).to_lower()
	if q in cat:
		return 100 + cat.find(q)
	var desc: String = str(cmd.get("description", "")).to_lower()
	if q in desc:
		return 200
	var kw: String = str(cmd.get("keywords", "")).to_lower()
	if q in kw:
		return 300
	return -1


func run(id: String) -> bool:
	for cmd in _commands:
		if cmd.get("id", "") == id:
			var handler = cmd.get("handler")
			if handler is Callable:
				handler.call()
				return true
	return false


func get_all() -> Array:
	return _commands.duplicate()


func group_by_category(cmds: Array) -> Dictionary:
	var groups := {}
	for cmd in cmds:
		var cat: String = str(cmd.get("category", "General"))
		if not groups.has(cat):
			groups[cat] = []
		groups[cat].append(cmd)
	return groups
