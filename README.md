# Copernicus — Robot Design Interface

**Copernicus** is an **operating system for robotics**, built on [Godot 4](https://godotengine.org/):
a small **kernel** in the middle, **apps** (plugins) that run on it, and **robots** that plug in through
ROS 2 and swappable robotics backends — with a blockchain + RaaS layer that takes a design from
simulation into a real-world robot.

Named after Nicolaus Copernicus, because it **centres** robotics development — open source, no
corporate lock-in, everything in one place.

> **Repository:** [github.com/PatrickMockridge/Copernicus](https://github.com/PatrickMockridge/Copernicus)

## Quick start

```bash
godot scenes/main.tscn
```

The main scene opens the 3D editor on top and the terminal at the bottom.

## Interface

- **Editor** — a 3D viewer for loading and inspecting robot models (URDF, MJCF, and the built-in
  robot library).
- **Terminal** — a Commodore-64-style command line (blue background, uppercase output, block cursor)
  at the bottom of the window.
- **Wallet** — a password keystore with BIP-39 mnemonic generation, used for transfers and on-chain
  operations.
- **Plugins** — Marketplace, Version Control, Coordination, RaaS, the robot library, and the AI
  assistant are plugins that can be enabled or disabled from the Plugins view.

## Terminal commands

Type `list` for the catalog or `help <command>` for details.

Built-in verbs:

```
open · load · back · mode · wireframe · grid · sensors · demo · tool · ros2 · plugins · list · help · clear
```

Plugin verbs — coordination (`register`, `publish`, `claim`, `settle`), marketplace (`listings`,
`search`, `buy`), VCS (`status`, `log`, `commit`, `push`, `pull`, `clone`).

See [the terminal user manual](docs/terminal-user-manual.md) and
[specification](docs/spec/07-terminal.md).

## The Workbench Loop

The application includes a 10-step progression from **First Light** to **Ship**. Each step is an
objective with a checklist shown in the side bar; completing a step advances to the next.

## The structure

Copernicus is a kernel with apps and robots around it (see
[`docs/spec/00-kernel.md`](docs/spec/00-kernel.md)).

### Kernel (always present)

- **Viewport** — the 3D robot editor (load, inspect, select, move).
- **Terminal** — the verb-first command line and the log.
- **Screen schema** — the windowing (rail · journal · stage · assistant · log · status).
- **AI assistant** — an agentic Claude assistant that edits a workspace.
- **Wallet + RaaS** — on-chain identity, funds, and robotics-as-a-service.

### Apps (plugins)

The robot library, Marketplace, Coordination, Version Control, and RaaS — opt-in surfaces that mount
on the kernel. URDF and MJCF import, and the built-in robots (TurtleBot, Arm6, Quadruped, Gripper,
Drone).

### Robots (backends, plugged in via ROS 2)

Swappable robotics capability, selected with `tool <x>`:

| Backend | `tool` |
|---|---|
| Inverse kinematics (CCD, FABRIK, MoveIt) | `ik` |
| Physics (Godot, PyBullet, CUDA) | `physics` |
| Sensors (LIDAR, camera, IMU, fusion) | — |
| Navigation (A*, Nav2) | `nav` |
| Reinforcement learning (DQN, PPO, SAC) | `gpu` |
| Industrial robots (MOTOMAN, OPC-UA) | `industrial` |
| Omniverse / USD | `omni` |
| ROS 2 bridge | `ros2` |

The ROS 2 bridge publishes `/robot/odom`, `/robot/scan`, `/robot/image_raw`, `/robot/imu` and
subscribes to `/robot/cmd_vel`.

### The economic layer

RChain coordination and the marketplace, with **robotics-as-a-service**: register a robot, publish a
job, claim it, and settle a work-metered fee — the path from a design in simulation to a robot earning
in the real world.

## Architecture

```
Copernicus
├── scripts/
│   ├── core/                  # module.gd, module_registry.gd, task_runner.gd
│   ├── ui/                    # main_shell.gd, ui_theme.gd, command_registry.gd, ...
│   │   ├── cli/               # cli.gd — the terminal command engine
│   │   ├── navigation/        # route.gd, navigation_model.gd
│   │   └── components/        # UiPanel, UiLabel, UiConsole, TerminalInput, ...
│   ├── scenarios/             # scenario.gd, scenario_service.gd, progression_model.gd, ...
│   ├── robots/                # robot_library.gd, robot_factory.gd, factories/
│   ├── rchain/                # rchain_service.gd, rchain_wallet.gd, rnode_client.gd, ...
│   ├── coordination/          # coordination_core.gd, rchain_coordination.gd, mock
│   ├── marketplace/           # marketplace_core.gd, backends/, ui/
│   ├── vcs/                   # vcs_backend.gd, git_vcs.gd, ariadne_vcs.gd
│   ├── gpu/ ik/ nav/ physics/ sensors/   # domain backends
│   └── test_*.gd              # headless tests
├── scenes/                    # main.tscn + selectors + demos
├── addons/                    # godot_ros2, GameAI, hyperobject, rchain, industrial, ...
└── docs/                      # spec/, terminal manuals, feature guides
```

### Subsystems

- `ModuleRegistry` / `CopernicusModule` — backends self-register via `_static_init()`.
- `CommandRegistry` / `Cli` — the terminal engine (tokenize → dispatch → errors).
- `NavigationModel` / `Route` — view navigation with back and breadcrumb.
- `ScenarioService` / `ProgressionModel` — the Workbench Loop ladder.
- `TaskRunner` — background-task execution (worker threads, results marshalled to the main thread).
- `UiTheme` — color/font/spacing/stylebox tokens used by the UI components.

### Plugin system

Backends implement `CopernicusModule` and self-register via `_static_init()`. A plugin can
contribute a view (`Route`), commands (`CopernicusModule.get_commands()`), and/or a status item. The
Plugins view enables and disables plugins (state persisted to `user://plugins.json`). See the
[plugin guide](docs/development/plugin-guide.md) and the
[terminal developer manual](docs/terminal-developer-manual.md).

## Documentation

- **Specification** — `docs/spec/01–07`: Godot model, inventory, signal backbone, components, state
  transitions, deterministic rendering, terminal.
- **Terminal** — [user manual](docs/terminal-user-manual.md),
  [developer manual](docs/terminal-developer-manual.md).
- **Getting started** — [quick start](docs/quick-start.md), [guide](docs/01-getting-started.md).
- **Concepts / architecture** — [concepts](docs/02-concepts.md), [architecture](docs/03-architecture.md).
- **Feature guides** — robots, physics, sensors, RL, navigation, industrial, ROS 2, marketplace,
  RChain.

## Development

```bash
godot --headless --script res://scripts/test_cli.gd        # terminal CLI
godot --headless --script res://scripts/test_navigation.gd # navigation model
godot --headless --script res://scripts/test_scenarios.gd  # workbench loop
godot --headless --script res://scripts/test_state.gd      # state transitions
godot --headless --script res://scripts/test_shell.gd      # routes / plugins
godot --headless --script res://scripts/test_ik.gd         # arm IK
godot --headless --script res://scripts/test_shortcuts.gd  # viewport shortcuts
godot --headless --script res://scripts/test_mesh.gd       # mesh translation (STL/OBJ/DAE)
godot --headless --script res://scripts/test_rchain.gd     # crypto + node (skips without node)
```

The RChain crypto layer is a Rust GDExtension in `addons/rchain/gdext`; build with
`bash addons/rchain/build.sh`.

## Requirements

| Component | Version | Notes |
|---|---|---|
| Godot | 4.4+ | headless supported |
| Rust | 1.95+ | RChain crypto GDExtension |
| RNode | latest | optional, on-chain coordination |
| Python | 3.10+ | PyBullet/PyTorch backends |
| ROS 2 | Jazzy/Humble | optional |
| CUDA | 11.8+ | GPU acceleration |

## License

Copernicus is distributed under [GNU AGPLv3](LICENSE).
