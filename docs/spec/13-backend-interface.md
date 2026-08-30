# 13 — Robotics Backend / Kernel Interface

This document defines **how robotics backends interact with the kernel** — the single contract that
physics, IK, sensors, navigation, RL, industrial, ROS2, and Omniverse all obey. It builds on `00`
(kernel), `03` (signals/async), `12` (the module registry), and drives the backend consolidation.

## 1. The module contract

A backend is a `CopernicusModule` (`scripts/core/module.gd`) with five static identity methods plus an
optional command list:

| Member | Meaning |
|---|---|
| `get_module_name()` / `get_module_description()` | human label |
| `is_available()` | **honest** — false if a runtime dep (Python, ROS2, CUDA, a node) is missing |
| `get_requirements()` | what `is_available()` checks |
| `get_module_category()` | the `ModuleRegistry` category (`physics`, `ik`, `nav`, `gpu`, …) |
| `get_commands()` | extra terminal verbs (e.g. `status`, `listings`) |

**Contract:** a backend registers itself in `static _static_init()` via
`ModuleRegistry.register(category, id, script)`. The kernel never imports a backend class; it resolves
via `ModuleRegistry.create(category, id, config)`.

## 2. Selection

`scripts/ui/base_selector.gd` (`BaseSelector`, a `ModalLayer`) is the selection UI. The kernel opens it
with `tool <category>` (or Tools → …), the user picks a backend, and the kernel instantiates it.

**Contract:** `tool ik` / `tool physics` / `tool nav` / `tool gpu` / `tool industrial` / `tool omni` all
resolve to the same `ModuleRegistry.create` path; a selector lists only `is_available()` backends (no
"coming soon", no dead entries).

## 3. What the kernel hands a backend

- **The robot tree** — the loaded `Node3D` (e.g. `scripts/urdf_to_physics.gd` converts it to backend
  bodies/joints).
- **The signal backbone** — backends emit results on the main thread (`03`).
- **The task runner** — long work goes through `RChainService.run_async` (the `TaskRunner`), never the
  main thread.

## 4. Per-category backends

| Category | Backends | Key files |
|---|---|---|
| physics | Godot (Jolt), PyBullet, PyBullet-CUDA | `scripts/physics/` |
| ik | analytical CCD/FABRIK, MoveIt | `scripts/ik/` |
| nav | A*, Nav2 | `scripts/nav/` |
| gpu/RL | PyTorch DQN/PPO/SAC, Isaac Gym | `scripts/gpu/backends/` |
| industrial | Mock, MOTOMAN, OPC-UA | `addons/industrial/` |
| ros2 | TCP/UDP bridge, native rclpy | `addons/godot_ros2/`, `addons/ros2_native/` |
| omni | USD import/export/validate, Kit sync | `addons/omni/` |

**Contract:** sensors are a hybrid — the debug overlays (`scripts/lidar_debug.gd` etc.) are kernel-side
viewer aids; the ROS2-facing sensors are backends. The viewer's built-in CCD is a convenience, not a
replacement for the `ik` backend.

## 5. Consolidation target

The refactor that follows this spec makes every backend:

1. a clean `CopernicusModule` with honest `is_available()`;
2. reachable only through `ModuleRegistry` + `BaseSelector`;
3. signal-driven (results on the main thread);
4. free of "coming soon" placeholder entries and dead backends.

**Falsifiable:** `grep "coming soon" scripts/` returns nothing; `grep -r "ModuleRegistry.create" scripts/`
shows selectors resolve backends by id; `scripts/test_ik.gd` / `test_navigation.gd` pass headlessly.

## See also

- `docs/development/plugin-guide.md` (build a backend), `docs/spec/03-signal-backbone.md`,
  `scripts/core/module.gd`, `scripts/core/module_registry.gd`, `scripts/ui/base_selector.gd`.
