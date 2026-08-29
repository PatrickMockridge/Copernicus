# command_registry.gd
# Autoload singleton — the shared command store. The terminal engine (Cli) and
# the command palette both query it. A command is {name, syntax, description,
# category, handler: Callable(args, out) -> bool}.

extends Node

var _commands: Array = []


func register(cmd: Dictionary) -> void:
	if not cmd.has("name") or not cmd.has("handler"):
		push_error("CommandRegistry.register: command needs 'name' and 'handler'")
		return
	unregister(cmd["name"])
	_commands.append(cmd)


func unregister(name: String) -> void:
	for i in range(_commands.size() - 1, -1, -1):
		if _commands[i].get("name", "") == name:
			_commands.remove_at(i)


## Lookup by verb (case-insensitive).
func find_by_name(name: String) -> Dictionary:
	var q := name.to_lower()
	for cmd in _commands:
		if str(cmd.get("name", "")).to_lower() == q:
			return cmd
	return {}


## Run a command's handler with args, writing output/errors through `out`.
func run(name: String, args: Array = [], out: Callable = Callable()) -> bool:
	var cmd := find_by_name(name)
	if cmd.is_empty():
		return false
	var handler = cmd.get("handler")
	if handler is Callable:
		return bool(handler.call(args, out))
	return false


## Fuzzy search over name/syntax/category/description (for the palette).
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
	var name: String = str(cmd.get("name", "")).to_lower()
	if q in name:
		return name.find(q)
	var syntax: String = str(cmd.get("syntax", "")).to_lower()
	if q in syntax:
		return 100 + syntax.find(q)
	var cat: String = str(cmd.get("category", "")).to_lower()
	if q in cat:
		return 200 + cat.find(q)
	var desc: String = str(cmd.get("description", "")).to_lower()
	if q in desc:
		return 300
	return -1


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
