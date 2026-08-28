Fix the GameAISDK addon so it compiles under Godot 4.4

The addon is at `addons/GameAISDK/addons/gameai/core/ai.gd` and
`addons/GameAISDK/addons/gameai/integrations/ros/ros_ai.gd`.

## Critical Path Error — Wrong Preload Paths

The submodule is located at `addons/GameAISDK/addons/gameai/` — the
GameAISDK package is nested one level deep inside the submodule. The
preload paths must include the full relative path from the project root:

```
Correct:  res://addons/GameAISDK/addons/gameai/core/config.gd
Wrong:    res://addons/gameai/core/config.gd  ← current error
```

## Errors

The scripts fail to compile because they reference types that are not
defined within the addon itself:

- `AIConfig` — used in `ai.gd` lines 9, 15, 33
- `HttpClient` — used in `ai.gd` lines 10, 16
- `Result` — used extensively throughout both files as a return type
- `ROSAI` class_name in `ros_ai.gd` hides the autoload singleton of the
  same name in `project.godot`

## Preload Path Fix Required

All `preload()` calls in both files must use the FULL path including the
`GameAISDK` submodule directory:

In `ai.gd`:
```
const AIConfig = preload("res://addons/GameAISDK/addons/gameai/core/config.gd")
const HttpClient = preload("res://addons/GameAISDK/addons/gameai/core/http_client.gd")
const Result = preload("res://addons/GameAISDK/addons/gameai/core/result.gd")
```

In `ros_ai.gd`:
```
const Result = preload("res://addons/GameAISDK/addons/gameai/core/result.gd")
```

## What needs to be done

1. Define or import the missing types. In Godot 4, `Result` is not a
   built-in — it must be either:
   - A custom class defined within the project (e.g. a simple
     `{success: bool, value: Variant, error: String}` variant or an
     `Result` class with `ok()` / `err()` static constructors)
   - Replaced with a Godot 4 native approach (e.g. returning `Variant`
     and using `null` checks, or using `Callable` for error callbacks)

2. `AIConfig` and `HttpClient` — check if these should be classes
   defined in other files within the GameAISDK addon that are not being
   loaded. They may have been removed or renamed in a Godot 4 port.

3. The `ROSAI` class_name conflict — either rename the class in
   `ros_ai.gd` to something like `ROSAIBehavior` or remove the class_name
   declaration if `ROSAI` is only meant to be an autoload.

4. Commit and push the fix to the GitHub repository at
   https://github.com/PatrickMockridge/Copernicus.

## Relevant files

- `addons/GameAISDK/addons/gameai/core/ai.gd`
- `addons/GameAISDK/addons/gameai/integrations/ros/ros_ai.gd`
- `project.godot` — autoload section shows `ROSAI` is registered as an
  autoload pointing to `ros_ai.gd`
