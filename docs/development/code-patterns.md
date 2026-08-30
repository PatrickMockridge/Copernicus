# Code Patterns

Correct patterns for Godot 4.3 compatibility. These patterns replace deprecated or incompatible syntax.

## Signals + Thread (replaces async/await)

Godot 4.3 rejects `async func` declarations with "Unexpected identifier in class body". Use Thread + Signal instead.

### Pattern: Thread with Deferred Signal

```gdscript
var _thread: Thread
signal completed(result: Variant)

func do_async_work() -> void:
    _thread = Thread.new()
    _thread.start(callable(self, "_worker_thread"))

func _worker_thread() -> void:
    var result = blocking_work()
    call_deferred("emit_signal", "completed", result)
```

### Pattern: Bridge Connection

```gdscript
signal bridge_connection_completed(success: bool)
var _connection_thread: Thread

func connect_bridge() -> void:
    _connection_thread = Thread.new()
    _connection_thread.start(callable(self, "_connect_thread"))

func _connect_thread() -> void:
    var success = do_blocking_tcp_connect()
    call_deferred("emit_bridge_connection_completed", success)
```

### Pattern: Initialization with Relay

```gdscript
signal initialization_completed(success: bool)

func initialize() -> void:
    _bridge_client.bridge_connection_completed.connect(_on_bridge_connection_completed)
    _bridge_client.connect_bridge()

func _on_bridge_connection_completed(success: bool) -> void:
    if success:
        _node.set_bridge_client(_bridge_client)
    initialization_completed.emit(success)
```

---

## preload + new() (replaces autoload singletons)

Godot headless doesn't register autoloads as `Engine.get_singleton()` — they return null. Use preload + new() instead.

### Pattern: Loading the AI agent

```gdscript
const AgentController = preload("res://scripts/ai/agent.gd")

func _run(task: String, history: Array) -> Dictionary:
    var agent := AgentController.new()
    return agent.run(task, history)   # {ok, error, text, messages, events}
```

### Pattern: Using Result

```gdscript
const Result = preload("res://addons/primitives/result.gd")

func _on_response(r: Result) -> void:
    if r.is_ok():
        process_success(r.get_data())
    else:
        handle_error(r.get_error())
```

---

## Result.new() (replaces static ok()/err())

The Result class no longer has static `ok()` and `err()` methods — they caused circular reference issues at class definition time.

### Pattern: Returning Success

```gdscript
return Result.new(true, {
    "content": content,
    "provider": "anthropic"
})
```

### Pattern: Returning Failure

```gdscript
return Result.new(false, null, {
    "code": -1,
    "message": "Connection failed"
})
```

### Pattern: Forwarding Errors

```gdscript
func some_function() -> Result:
    var response = _http.post(url, headers, body)
    if response.is_err():
        return response  # Forward the error
    return Result.new(true, parse_response(response.ok_value()))
```

### Result API

| Method | Returns | Description |
|--------|---------|-------------|
| `is_ok()` | bool | True if success |
| `is_err()` | bool | True if failure |
| `ok_value()` | Variant | The success value |
| `err_value()` | Dictionary | Error details with `code` and `message` |
| `get_or_default(default)` | Variant | Returns ok_value or default if err |

---

## Signal-Based Callbacks (async communication without coroutines)

### Pattern: Replaying agent events on the main thread

```gdscript
func _on_run_done(result) -> void:
    if result == null:
        _show_error("worker returned nothing")
        return
    if not result.get("ok", false):
        _show_error(str(result.get("error", "")))
        return
    for e in result.get("events", []):
        _apply_event(e)   # message / tool_called / tool_result
```

---

## Common Fixes

### HTTP Response Parsing

```gdscript
func _parse_anthropic_response(response_text: String) -> Result:
    var json = JSON.parse_string(response_text)
    if json == null:
        return Result.new(false, null, {"code": -3, "message": "Failed to parse response"})
    if json.has("error"):
        return Result.new(false, null, {"code": -4, "message": json.error.message})
    return Result.new(true, json)
```

### Thread-Safe Signal Emission

Always use `call_deferred` when emitting signals from a thread:

```gdscript
func _worker_thread() -> void:
    var result = compute_value()
    call_deferred("emit_signal", "completed", result)
```

Never emit signals directly from background threads — it can cause crashes.

---

## What Not to Use

| Deprecated | Reason | Use Instead |
|------------|--------|-------------|
| `async func` | "Unexpected identifier" in Godot 4.3 | Thread + Signal |
| `await` | Same as above | Thread + Signal |
| `Engine.get_singleton()` | Returns null in headless | preload + new() |
| `Result.ok()` static | Circular reference at class def | `Result.new(true, value)` |
| `Result.err()` static | Circular reference at class def | `Result.new(false, null, error)` |