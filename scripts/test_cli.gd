# test_cli.gd
# Headless unit test for the terminal CLI engine (tokenize + execute + errors +
# help/catalog). Run: godot --headless --script res://scripts/test_cli.gd

extends SceneTree

var _fails := 0


func _init() -> void:
	var registry = load("res://scripts/ui/command_registry.gd").new()
	var cli = Cli.new(registry)
	registry.register({"name": "hello", "syntax": "", "description": "say hello", "category": "test", "handler": _hello})
	registry.register({"name": "echo", "syntax": "<text>", "description": "echo text", "category": "test", "handler": _echo})

	# tokenizer
	_ok(Cli.tokenize("hello world") == ["hello", "world"], "tokenize simple")
	_ok(Cli.tokenize("load \"my arm.urdf\"") == ["load", "my arm.urdf"], "tokenize quoted")
	_ok(Cli.tokenize("  hello   world  ") == ["hello", "world"], "tokenize skips whitespace")
	_ok(Cli.tokenize("") == [], "tokenize empty")

	# execute: success
	var out1: Array = []
	_ok(cli.execute("hello", func(l): out1.append(l)), "execute hello returns true")
	_ok(out1 == ["hello!"], "hello output")

	# execute: unknown command
	var out2: Array = []
	_ok(cli.execute("nope", func(l): out2.append(l)) == false, "unknown returns false")
	_ok(out2 == ["?UNKNOWN COMMAND"], "unknown writes ?UNKNOWN COMMAND")

	# execute: syntax error (missing required arg)
	var out3: Array = []
	_ok(cli.execute("echo", func(l): out3.append(l)) == false, "echo (no args) returns false")
	_ok(out3 == ["?SYNTAX ERROR"], "echo writes ?SYNTAX ERROR")

	# execute: with arg
	var out4: Array = []
	_ok(cli.execute("echo hi", func(l): out4.append(l)), "echo arg returns true")
	_ok(out4 == ["hi"], "echo arg output")

	# help + catalog
	_ok(cli.help_lines("echo").size() == 2, "help_lines has syntax + description")
	_ok(cli.help_lines("nope") == ["?UNKNOWN COMMAND"], "help unknown writes ?UNKNOWN COMMAND")
	_ok(cli.catalog_lines().size() >= 3, "catalog lists category + commands")

	if _fails == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES: ", _fails)
		quit(1)


func _hello(_args: Array, out: Callable) -> bool:
	out.call("hello!")
	return true


func _echo(args: Array, out: Callable) -> bool:
	if args.is_empty():
		out.call("?SYNTAX ERROR")
		return false
	out.call(str(args[0]))
	return true


func _ok(cond: bool, name: String) -> void:
	if cond:
		print("  PASS  ", name)
	else:
		print("  FAIL  ", name)
		_fails += 1
