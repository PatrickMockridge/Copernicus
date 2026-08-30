# Copernicus — AI Entrypoint

> **Read this first.** This page is the orientation point for AI agents (and humans) working in this
> repository. It gives you the model, the map, the rules, and the gotchas in one place. Everything else
> hangs off [`spec/00-kernel.md`](spec/00-kernel.md).

## 1. What this is

Copernicus is an open-source **operating system for robotics**, built on Godot 4. One sentence: a small
**kernel** sits in the middle; **apps (plugins)** run on it; **robots** plug in through ROS 2 and
swappable backends; and a **blockchain + RaaS** layer takes a design from simulation into a real-world
robot. It is free, open, and runs anywhere — no single company owns your robot or your workflow.

## 2. The model (the centre of gravity)

There is one rule: **a small, fixed kernel; everything else plugs into it.**

| Layer | What it is | Spec |
|-------|-----------|------|
| **Kernel** | viewport, terminal, screen schema, AI assistant, wallet + RaaS | `spec/00-kernel.md` |
| **Apps (plugins)** | robot library, marketplace, coordination, VCS, RaaS — opt-in UI surfaces | `spec/12-plugins.md` |
| **Robots (backends)** | physics, IK, sensors, nav, RL, industrial, Omniverse, ROS 2 — selected with `tool <x>` | `spec/13-backend-interface.md` |
| **Economic layer** | blockchain + RaaS (RChain; AO/Arweave dormant) | `spec/11-wallet-raas.md` |

And there is one **command layer**: everything is a **verb** in the terminal; the GUI just types the
words (`spec/07-terminal.md`).

## 3. Directory map

```
scripts/
├── core/          module.gd, module_registry.gd, task_runner.gd, settings_store.gd, python_bridge.gd
├── ui/            main_shell.gd, ui_theme.gd, command_registry.gd, command_palette.gd,
│   │              modal_layer.gd, base_selector.gd, toast.gd, confirm_dialog.gd, ...
│   ├── cli/       cli.gd — the terminal command engine
│   ├── navigation/  navigation_model.gd, route.gd
│   └── components/  UiPanel, UiLabel, UiConsole, TerminalInput, ...
├── scenarios/     scenario.gd, scenario_service.gd, progression_model.gd, scenario_evaluator.gd
├── robots/        robot_library.gd, robot_factory.gd, factories/
├── ai/            agent.gd, anthropic_client.gd, tools.gd — the agentic Claude assistant
├── rchain/        rchain_service.gd, rchain_wallet.gd, rnode_client.gd, rholang_sdk.gd, ...
├── coordination/  coordination_core.gd, rchain_coordination.gd, mock_coordination.gd
├── marketplace/   marketplace_core.gd, backends/, ui/
├── vcs/           vcs_backend.gd, git_vcs.gd, ariadne_vcs.gd
├── gpu/ ik/ nav/ physics/ sensors/   # domain backends (abstract base + impls)
├── viewport/      shortcut_manager.gd, gizmo.gd
├── mesh/          mesh_translator.gd, stl_parser.gd, obj_parser.gd, dae_parser.gd
└── test_*.gd      # headless tests
scenes/            main.tscn + selectors + demos
addons/            godot_ros2, rchain, industrial, primitives, omni, demo_framework
                   (GameAI, hyperobject, ROSCoder — dormant)
docs/              spec/ (00–13), manuals, feature guides
```

## 4. Key subsystems & autoloads

**Autoloads** (registered in `project.godot`):

| Autoload | File | Role |
|----------|------|------|
| `ModuleRegistry` | `scripts/core/module_registry.gd` | backend self-registration + `create()` |
| `CommandRegistry` | `scripts/ui/command_registry.gd` | terminal verb dispatch |
| `RobotLibrary` | `scripts/robots/robot_library.gd` | built-in robot catalog |
| `ScenarioService` | `scripts/scenarios/scenario_service.gd` | Workbench Loop progression |
| `RChainService` | `scripts/rchain/rchain_service.gd` | RChain coordination + task runner |
| `UiTheme` | `scripts/ui/ui_theme.gd` | design tokens (color/font/spacing/stylebox) |
| `EnvService` | `addons/primitives/env/env_service.gd` | environment config |
| `GodotROS2` | `addons/godot_ros2/godot_ros2.gd` | ROS 2 bridge |

(`GameAI` / `ROSAI` are still listed in `project.godot` but **dormant** — do not use.)

**Subsystems:**

- `ModuleRegistry` / `CopernicusModule` / `BaseSelector` — backends self-register in `_static_init()`.
- `CommandRegistry` / `Cli` — the terminal engine (tokenize → dispatch → errors).
- `NavigationModel` / `Route` — view navigation with back and breadcrumb.
- `ScenarioService` / `ProgressionModel` — the 10-step Workbench Loop.
- `TaskRunner` — background threads; results marshalled to the main thread.

## 5. Conventions (how to write code here)

- **Backends** extend a domain abstract base (`PhysicsBackend`, `IKSolver`, `NavPlanner`, …) which
  extends `CopernicusModule`. Implement five static methods (`get_module_name`, `get_module_description`,
  `is_available`, `get_requirements`, `get_module_category`), self-register in `static func _static_init()`
  via `ModuleRegistry.register(category, id, script)`, and be reachable **only** through
  `ModuleRegistry.create(category, id, config)`. Never import a backend class directly. `is_available()`
  must be an honest runtime check (no "coming soon" entries).
- **Everything is a verb** in the terminal; the GUI types the words. New commands come from
  `CopernicusModule.get_commands()`.
- **Styling** uses `UiTheme` tokens — no raw colors. Deterministic rendering rules live in
  `spec/06-deterministic-rendering.md`.
- **Long work** goes through the `TaskRunner` (`RChainService.run_async`), never the main thread; results
  are emitted as signals on the main thread (`spec/03-signal-backbone.md`).

## 6. Gotchas (things that will bite you)

- **Autoload names are NOT global identifiers under `--script` mode.** Scripts run headlessly via
  `godot --headless --script` cannot see autoloads like `EnvService` — use `OS.get_environment()` there.
- **`SettingsStore.load()` / `save()` are renamed `read()` / `write()`** — they collided with Godot's
  global `load()`.
- **GDScript**: no `String.strip_prefix` (use `trim_prefix`); `_get` collides with `Object._get(StringName)`
  (rename to e.g. `_http_get`); don't name a method `_signer` if a parent declares `var _signer`.
- **Viewport**: the context menu is viewport-owned but lives in `scripts/composite_workspace.gd` (a
  `PopupMenu` can't be a child of `SubViewport` content). Shortcuts are consumed in the shell's
  `_unhandled_input` (SubViewport key routing is unreliable).
- **`UiTheme.color()` `push_error`s on an unknown token** — routing a literal color to a token is
  intentional.

## 7. Run & verify

```bash
godot scenes/main.tscn                       # the kernel shell

# Headless tests
godot --headless --script res://scripts/test_cli.gd
godot --headless --script res://scripts/test_navigation.gd
godot --headless --script res://scripts/test_scenarios.gd
godot --headless --script res://scripts/test_state.gd
godot --headless --script res://scripts/test_shell.gd
godot --headless --script res://scripts/test_ik.gd
godot --headless --script res://scripts/test_shortcuts.gd
godot --headless --script res://scripts/test_mesh.gd
godot --headless --script res://scripts/test_rchain.gd       # skips without a node

# Docs book
mdbook build

# RChain crypto GDExtension (Rust)
bash addons/rchain/build.sh
cd addons/rchain/gdext && cargo test
```

## 8. Doc map

- **Spec (the anchor)** — `docs/spec/00–13`: kernel, godot model, inventory, signal backbone,
  components, state transitions, deterministic rendering, terminal, viewport, screen schema, AI
  assistant, wallet+RaaS, plugins, backend interface.
- **Manuals** — `interface-user-manual.md`, `terminal-user-manual.md`, `viewport-user-manual.md`,
  `ai-assistant-user-manual.md`.
- **Case studies** — `case-study-robot-arm.md`, `case-study-turtlebot.md`.
- **Development** — `development/plugin-guide.md` (build a backend), `development/code-patterns.md`,
  `terminal-developer-manual.md`.
- **Feature guides** — `robots/`, `physics/`, `sensors/`, `rl/`, `navigation/`, `industrial/`, `ros2/`,
  `omni/`, `rchain/`, `blockchain/`.

## 9. Dead / dormant — do NOT build on these

| Term | Status | Superseded by |
|------|--------|---------------|
| `GameAI`, `ROSAI`, `ROSCoder` | dormant | `scripts/ai/` (agent.gd, anthropic_client.gd, tools.gd) |
| `AO`, `Arweave`, `Hyperobject`, `AOMarketplace` | dormant | RChain (`scripts/rchain/`, `scripts/marketplace/backends/rchain_marketplace.gd`) |
| `CopernicusTheme` | gone | `UiTheme` (`scripts/ui/ui_theme.gd`) |
| `UiField`, `UiModal`, `UiStageRail` | gone | `ModalLayer` + `scripts/ui/components/` |
| `joint_panel.gd`, `context_menu_requested` | gone | viewer `set_joint_rotation` / `zero_all_joints`; `viewport_action` signal |
