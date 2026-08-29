# Copernicus Terminal — Developer Manual

This guide explains how to expose your module's (or plugin's) functionality as terminal commands.
The full contract is in `docs/spec/07-terminal.md`.

## 1. The command shape

A command is a `Dictionary`:

```gdscript
{
	"name": "register",            # the verb typed at the prompt (unique)
	"syntax": "<robot>",           # usage shown by `help`
	"description": "Register a robot on-chain",
	"category": "coordination",    # catalog group
	"handler": _cmd_register,      # static Callable(args, out) -> bool
}
```

The handler signature:

```gdscript
static func _cmd_register(args: Array, out: Callable) -> bool:
	# args   = the tokens after the verb (already parsed; quotes handled)
	# out    = write a line to the terminal with out.call(line)
	# return = true on success, false on failure
```

## 2. Contributing commands

Override the static `get_commands()` on your `CopernicusModule` subclass:

```gdscript
static func get_commands() -> Array:
	return [
		{"name": "register", "syntax": "<robot>", "description": "Register a robot on-chain", "category": "coordination", "handler": _cmd_register},
	]
```

The shell collects these via `ModuleRegistry.get_contributed_commands()` and registers them into the
terminal and palette automatically. No other wiring is needed.

## 3. Errors

Write `?`-prefixed errors through `out` and return `false`:

```gdscript
static func _cmd_register(args: Array, out: Callable) -> bool:
	if args.is_empty():
		out.call("?SYNTAX ERROR")
		return false
	var backend = ModuleRegistry.create("coordination", "RChainCoordination", {})
	if backend == null:
		out.call("?COORDINATION UNAVAILABLE")
		return false
	var r = backend.register_robot({"name": str(args[0])})
	if r.is_ok():
		out.call("registered " + str(args[0]))
		return true
	out.call("?ERROR: " + str(r.get_error()))
	return false
```

Use `?SYNTAX ERROR` for a missing required argument, `?BAD ARGUMENT` for an unknown value, and a
descriptive `?ERROR: …` for a backend failure.

## 4. Guidelines

- `handler` must be a **static** Callable — `get_commands()` is called on the module *script*, not on
  an instance. To act on instance state, obtain it inside the handler (e.g. `ModuleRegistry.create`)
  or read a shared autoload via `get_node("/root/…")`.
- Give every command a non-empty `syntax` and a one-line `description` (they drive `list`/`help`).
- Return a `bool` and write `?`-errors on failure — never rely on silent failure.
- Prefer a small, focused verb set over many one-off commands.

## 5. Verifying

```bash
godot --headless --script res://scripts/test_cli.gd    # tokenizer + execute + errors + help
godot --headless res://scenes/main.tscn                # launch; type `list` and your new verb
```
