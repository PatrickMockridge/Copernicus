# cli.gd
# The terminal command engine: tokenize a line, dispatch to a command, and
# format the catalog/help. Operates on the command store (CommandRegistry) it
# is given, so it stays headless-testable.

class_name Cli
extends RefCounted

var _registry  # CommandRegistry (find_by_name / get_all / group_by_category)


func _init(registry) -> void:
	_registry = registry


## Split a line into tokens: whitespace-separated; a double-quoted token keeps spaces.
static func tokenize(line: String) -> Array:
	var tokens: Array = []
	var i := 0
	var n := line.length()
	while i < n:
		while i < n and (line[i] == " " or line[i] == "\t"):
			i += 1
		if i >= n:
			break
		if line[i] == '"':
			i += 1
			var start := i
			while i < n and line[i] != '"':
				i += 1
			tokens.append(line.substr(start, i - start))
			i += 1  # skip the closing quote
		else:
			var start := i
			while i < n and line[i] != " " and line[i] != "\t":
				i += 1
			tokens.append(line.substr(start, i - start))
	return tokens


## Execute a line; write output/errors through `out`. Returns true on success.
func execute(line: String, out: Callable) -> bool:
	var tokens := tokenize(line)
	if tokens.is_empty():
		return true
	var name: String = tokens[0]
	var cmd: Dictionary = _registry.find_by_name(name)
	if cmd.is_empty():
		out.call("?UNKNOWN COMMAND")
		return false
	var handler = cmd.get("handler")
	if handler is Callable:
		return bool(handler.call(tokens.slice(1), out))
	return false


## The catalog as printable lines, grouped by category.
func catalog_lines() -> Array:
	var lines: Array = []
	var groups: Dictionary = _registry.group_by_category(_registry.get_all())
	for category in groups:
		lines.append(str(category) + ":")
		for cmd in groups[category]:
			lines.append("  %s %s" % [cmd.get("name", ""), cmd.get("syntax", "")])
	return lines


## Help text for one command, or the whole catalog when name is empty.
func help_lines(name: String) -> Array:
	if name.is_empty():
		return catalog_lines()
	var cmd: Dictionary = _registry.find_by_name(name)
	if cmd.is_empty():
		return ["?UNKNOWN COMMAND"]
	return [
		"%s %s" % [cmd.get("name", ""), cmd.get("syntax", "")],
		"  " + str(cmd.get("description", "")),
	]
