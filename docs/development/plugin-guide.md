# Copernicus Plugin Developer Guide

How to add a new backend module to Copernicus so it appears in the UI selector automatically.
No registration forms, no wiring up selectors, no touching 4 files. Write one class and you're done.

---

## Architecture Overview

Three moving parts:

```
CopernicusModule          ModuleRegistry           BaseSelector
(abstract base)           (autoload singleton)      (reusable UI)
      |                         |                        |
 Concrete backend -----> register("cat","id",script)     |
                              |                        |
                         get_available("cat") ------> populate radio list
                              |
                         create("cat","id",config) --> return instance
```

**CopernicusModule** (`scripts/core/module.gd`) defines the 5 static methods every backend implements:
`get_module_name()`, `get_module_description()`, `is_available()`, `get_requirements()`, `get_module_category()`.

**ModuleRegistry** (`scripts/core/module_registry.gd`) is an autoload singleton. Backends self-register in `_static_init()`. Selectors query `get_available(category)` to populate their UI. Factories call `create(category, id, config)` instead of match statements.

**BaseSelector** (`scripts/ui/base_selector.gd`) provides the shared selector UI: panel, title, radio list, Cancel/Apply buttons, ConfirmDialog-on-cancel. Domain selectors extend it and override 5-6 virtual methods.

Every domain also has an **abstract base class** (e.g. `PhysicsBackend`, `IKSolver`, `NavPlanner`) that extends `CopernicusModule` and defines the instance-method contract + signals for that domain.

---

## Creating a New Backend (Step by Step)

Let's add a Gazebo physics backend. We'll create one file and register it.

### Step 1: Create the backend class

`scripts/physics/gazebo_backend.gd`:

```gdscript
# gazebo_backend.gd
# Physics backend using Gazebo via ROS2

class_name GazeboBackend
extends PhysicsBackend

## ===== Module Identity (static contract) =====

static func get_module_name() -> String:
    return "Gazebo (ROS2)"

static func get_module_description() -> String:
    return "Industry-standard Gazebo physics via ROS2 bridge. High fidelity."

static func is_available() -> bool:
    # Check if gazebo ros2 package exists
    var output = []
    var result = OS.execute("ros2", ["pkg", "list"], output, true)
    if result == 0 and output.size() > 0:
        return "gazebo_ros" in output[0]
    return false

static func get_requirements() -> String:
    return "sudo apt install ros-{DISTRO}-gazebo-ros-pkgs ros-{DISTRO}-gazebo-ros2-control"

static func get_module_category() -> String:
    return "physics"

## ===== Self-Registration =====

static func _static_init():
    ModuleRegistry.register("physics", "GazeboBackend", preload("res://scripts/physics/gazebo_backend.gd"))

## ===== Instance =====

var _ros_node: Node
var _is_simulating: bool = false

func initialize(config: Dictionary) -> bool:
    # Set up ROS2 communication
    var topic = config.get("topic", "/gazebo/link_states")
    # ... setup code ...
    backend_initialized.emit(true)
    return true

func step_simulation(delta: float) -> void:
    # Publish/subscribe to Gazebo
    pass

func get_body_state(body_name: String) -> Dictionary:
    # Query Gazebo for link state
    return {}

func shutdown() -> void:
    _is_simulating = false
```

### Step 2: Restart Godot

`_static_init()` runs when the class is first loaded. The editor picks it up on restart.

### Step 3: Open the physics selector

GazeboBackend appears automatically. Available first (green), or unavailable (greyed out with requirements message).

Done. No other files touched.

---

## What Each Static Method Does

| Method | Purpose | Example return |
|--------|---------|---------------|
| `get_module_name()` | Display name in selector | `"PyBullet"` |
| `get_module_description()` | Description shown below name | `"Research-grade physics..."` |
| `is_available()` | Whether dependencies are installed | `true` or `false` |
| `get_requirements()` | Shown when unavailable | `"pip install pybullet"` |
| `get_module_category()` | Which selector category | `"physics"` |

`is_available()` should do a real check — run a shell command, try an import, test a connection. Never return a cached value. This is called every time the selector opens.

`get_requirements()` is a human-readable install instruction. Shown in tooltips or error messages.

---

## Creating a New Module Category

When you need a whole new domain (not just a backend within an existing one), you create three things:

### 1. Abstract base class

`scripts/newdomain/newdomain_backend.gd`:

```gdscript
class_name NewDomainBackend
extends CopernicusModule

## Signals for this domain
signal operation_started()
signal operation_complete(result: Variant)

## ===== Instance contract =====

func initialize(config: Dictionary) -> bool:
    return true

func do_thing(input: Variant) -> Variant:
    push_error("NewDomainBackend.do_thing() must be implemented")
    return null

func shutdown() -> void:
    pass

## ===== Module Identity =====

static func get_module_category() -> String:
    return "newdomain"

## Forwarding aliases (backward compat)
static func get_backend_name() -> String:
    return get_module_name()
```

### 2. Concrete backends

Create `scripts/newdomain/backends/my_backend.gd` extending `NewDomainBackend`. Same pattern as the Gazebo example above — override the 5 static methods, add `_static_init()`.

### 3. Selector UI

`scripts/newdomain/newdomain_selector.gd`:

```gdscript
class_name NewDomainSelector
extends BaseSelector

signal backend_selected(backend_class: String)

func _get_title() -> String:
    return "Select NewDomain Backend"

func _get_info_text() -> String:
    return "Choose which backend to use for newdomain operations."

func _get_button_group_name() -> String:
    return "newdomain_backend"

func _get_category() -> String:
    return "newdomain"

func _on_apply_pressed() -> void:
    backend_selected.emit(_selected_id)
    queue_free()

static func create_backend(id: String, config: Dictionary = {}) -> NewDomainBackend:
    return ModuleRegistry.create("newdomain", id, config)
```

That's ~20 lines. The BaseSelector handles all UI construction, option population from the registry, cancel confirmation, and default selection.

### Virtual methods you can override in BaseSelector

| Method | Default | When to override |
|--------|---------|-----------------|
| `_get_title()` | `"Select Module"` | Always |
| `_get_info_text()` | `""` | When you want help text below the list |
| `_get_button_group_name()` | `"module_selection"` | Always (keep unique per selector) |
| `_get_apply_text()` | `"Apply"` | When you want "Open", "Connect", etc. |
| `_get_category()` | `""` | Always — maps to ModuleRegistry category |
| `_populate_options(container)` | Auto-fills from registry | When you need hardcoded items too |
| `_on_option_selected(id)` | No-op | When you need side effects on selection |

### Adding hardcoded options alongside registry items

Override `_populate_options()` and call `super`:

```gdscript
func _populate_options(container: VBoxContainer) -> void:
    _add_option("coming_soon", "Coming Soon Backend", "Not yet available.", false)
    super._populate_options(container)
```

Hardcoded items appear before registry items by default. Call `super` first to reverse that.

---

## UI Utilities

Copernicus provides several reusable UI components. All are in `scripts/ui/`.

### CopernicusTheme (autoload)

Access globally as `CopernicusTheme`. Provides:

**Colors:**
- `TEXT_PRIMARY`, `TEXT_SECONDARY`, `TEXT_DISABLED`
- `BG_DARK`, `BG_CARD`, `BORDER_DIM`, `BORDER_CARD`
- `ACCENT`, `SUCCESS`, `WARNING`, `ERROR`

**Factory methods:**
- `make_title(text)` → Label (font_size 22, primary color)
- `make_heading(text)` → Label (font_size 18, primary color)
- `make_body(text)` → Label (font_size 14, secondary color, word wrap)
- `make_separator()` → HSeparator
- `make_button_row(cancel_text, confirm_text)` → HBoxContainer with Cancel/Apply buttons
- `style_panel(panel)` → applies dark panel StyleBox
- `style_card(panel)` → applies card StyleBox with border

### Toast

Non-blocking notification that slides in from the bottom:

```gdscript
Toast.show_toast(parent_node, "Backend connected", Toast.Level.SUCCESS)
Toast.show_toast(parent_node, "Connection failed: timeout", Toast.Level.ERROR, 6.0)
```

Levels: `INFO`, `SUCCESS`, `WARNING`, `ERROR`. Duration defaults to 4.0 seconds.

### ConfirmDialog

Modal confirmation with title, message, and two buttons:

```gdscript
var dialog = ConfirmDialog.ask(parent_node, "Delete Robot?", "This action cannot be undone.", "Delete", "Keep")
dialog.confirmed.connect(func(): _do_delete())
```

Signals: `confirmed()`, `dismissed()`. Pressing Escape triggers dismiss.

### LoadingOverlay

Full-screen spinner with message:

```gdscript
var overlay = LoadingOverlay.show_overlay(parent_node, "Publishing asset...")
# ... do work ...
overlay.dismiss()
```

---

## Code Conventions

### Class loading

Use `preload("res://path/to/script.gd")` for compile-time constants. Use `load()` only for runtime-determined paths.

When a class references itself inside a `static func`, use `load()` instead of `class_name`:

```gdscript
static func show_overlay(parent: Node, message: String):
    var overlay = load("res://scripts/ui/loading_overlay.gd").new()
    # NOT: var overlay = LoadingOverlay.new()  -- fails in headless mode
```

### Threading

Godot does not have threading in the traditional sense. For async work:
- Use `await` with timers or signals
- Use `OS.execute()` with subprocesses for external computation
- Never block the main thread

### Result pattern

Some modules use a simple `Result` class for error handling:
```gdscript
func do_thing() -> Result:
    if error_condition:
        return Result.err("Something went wrong")
    return Result.ok({"data": value})
```

### Naming

- Classes: `PascalCase`
- Methods/functions: `snake_case`
- Signals: `snake_case` (past tense for events: `backend_selected`, `simulation_stepped`)
- Constants: `UPPER_SNAKE_CASE`
- Private members: `_leading_underscore`
- File names: `snake_case.gd`

### Selector signal naming

Domain selectors emit a past-tense signal with the selected ID:
- PhysicsSelector: `backend_selected(backend_class: String)`
- IKSelector: `solver_selected(solver_class: String)`
- NavSelector: `planner_selected(planner_class: String)`

The `BaseSelector` base class emits `option_selected(id: String)` and `cancelled()`.

---

## Complete Walkthrough: GazeboBackend End to End

1. **Create the file**: `scripts/physics/gazebo_backend.gd` with the code from the example above.

2. **Open Godot editor**. The `_static_init()` fires, registering with ModuleRegistry.

3. **Open PhysicsSelector** in your UI. The selector calls `ModuleRegistry.get_available("physics")`, which iterates all registered physics backends, calls `get_module_name()` and `is_available()` on each, and returns a sorted list (available first).

4. **GazeboBackend appears** in the radio list. If Gazebo is installed, it shows as available. If not, it shows "Gazebo (ROS2) (Unavailable)" with the requirements text.

5. **User selects Gazebo and clicks Apply**. The selector emits `backend_selected("GazeboBackend")`.

6. **Your code creates the instance**:
   ```gdscript
   var backend = ModuleRegistry.create("physics", "GazeboBackend", {"topic": "/gazebo/link_states"})
   backend.initialize({"topic": "/gazebo/link_states"})
   ```
   `ModuleRegistry.create()` instantiates the GDScript and calls `initialize(config)` if the instance has that method.

---

## Verification Checklist

After creating a new backend, verify:

- [ ] `YourBackend.get_module_name()` returns the correct display name
- [ ] `YourBackend.is_available()` returns `true` when dependencies are present
- [ ] `ModuleRegistry.get_available("category")` includes your backend
- [ ] `ModuleRegistry.create("category", "YourBackend", config)` returns a working instance
- [ ] `ModuleRegistry.get_info("category", "YourBackend")` returns the info dict
- [ ] Selector UI shows your backend with correct name, description, and availability
- [ ] Available backends appear before unavailable ones
- [ ] Unavailable backends show "(Unavailable)" and are greyed out
- [ ] Cancel button with changed selection prompts "Discard Changes?"
- [ ] Cancel button without changes closes immediately
- [ ] Apply button emits the correct signal with the selected ID
- [ ] `godot --headless --quit` produces no parse errors
