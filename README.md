# Copernicus — Robot Design Interface

**Copernicus** is an open-source robot design interface built on [Godot 4](https://godotengine.org/).
It is a **terminal-first, plugin-based IDE for robots**: the **3D robot editor** and the **terminal**
are the two non-negotiable core surfaces, the **wallet** is the second pinned surface (funds at
risk), and everything else is an **opt-in plugin**.

Named after Nicolaus Copernicus — who placed the Sun at the centre of the solar system — Copernicus
places the **open-source community** at the centre of robot development.

> **Repository:** [github.com/PatrickMockridge/Copernicus](https://github.com/PatrickMockridge/Copernicus)

---

## What it is

- **A neovim-style IDE, not "corporate software".** The editor and terminal are always present; the
  chrome is minimal; features are plugins you opt into.
- **Terminal-first.** A Commodore-64-style command line (flat blue screen, uppercase output,
  blinking block cursor, `?`-prefixed errors) is the primary interface. Every GUI action maps to a
  terminal command, and plugins expose themselves through it.
- **Deterministic rendering.** The UI follows a formal component/token model
  (`docs/spec/06-deterministic-rendering.md`) so the rendered output is explicit — never left to the
  engine's implicit layout defaults.
- **Honest WYSIWYG.** One source of truth per piece of state (navigation, toggles, scenario
  progression); no inert controls, no lying readouts.

## Quick start

```bash
godot scenes/main.tscn
```

You get the **3D editor (top)** and the **terminal (bottom)**, which boots to a `READY.` prompt:

```
> list          # the command catalog
> help open     # help for one command
> open wallet   # open the wallet
> load arm6     # load the 6-DOF arm
> demo physics  # drive the differential-drive demo
```

The terminal is the foundation — see the [user manual](docs/terminal-user-manual.md) for the full
command reference.

## The terminal

A flat C64 screen (dark blue `#000060`, pale-blue text `#c8c8ff`, blinking block cursor). Built-in
verbs:

```
open · load · back · mode · wireframe · grid · sensors · demo · tool · ros2 · plugins · list · help · clear
```

Plugins add their own — coordination (`register`/`publish`/`claim`/`settle`), marketplace
(`listings`/`search`/`buy`), and VCS (`status`/`log`/`commit`/`push`/`pull`/`clone`). The formal spec
is [`docs/spec/07-terminal.md`](docs/spec/07-terminal.md); the authoring guide is
[`docs/terminal-developer-manual.md`](docs/terminal-developer-manual.md).

## Core surfaces

| Surface | Role |
|---|---|
| **Editor** | the 3D viewer — load, inspect, and configure robots |
| **Terminal** | the command line — the primary interface |
| **Wallet** | pinned — password keystore, BIP-39 mnemonic, transfers (funds at risk) |

Everything else — Marketplace, Version Control, Coordination, RaaS, the robot library, and the AI
assistant — is an **opt-in plugin**, reachable from the terminal and the command palette, and
disable-able from the **Plugins** view (state persisted).

## The Workbench Loop

A Zachtronics-style progression drives the app: a 10-step ladder from **First Light** to **Ship**,
where each step is an objective with a live checklist shown in the side bar. Completing a step
advances the ladder; the terminal (`mode`) and the side bar reflect it.

## Features

### Robot design
- **URDF / MJCF import** into the Godot scene tree.
- **Robot library** — TurtleBot, Arm6 (6-DOF arm), Quadruped, Gripper, Drone.
- **In-viewer IK** — CCD/FABRIK solve to a visible target marker.

### Physics simulation
| Backend | Speed | Accuracy | Use case |
|---|---|---|---|
| Godot Native | Fast | Game-grade | Design iteration |
| PyBullet | Medium | Research-grade | Manipulation |
| PyBullet CUDA | GPU | Research-grade | High-fidelity |

### Reinforcement learning
DQN, PPO, and SAC (PyTorch), plus Isaac Gym for GPU multi-robot training.

### Sensors
RTX LIDAR, RTX camera, IMU, and sensor fusion (Kalman).

### ROS 2
TCP/UDP bridge + native rclpy; publishes `/robot/odom` `/robot/scan` `/robot/image_raw`
`/robot/imu`, subscribes `/robot/cmd_vel`.

### Navigation, IK, industrial, Omniverse
A* / Nav2 · CCD / FABRIK / MoveIt · MOTOMAN / ABB / OPC-UA · USD export.

### Blockchain & coordination
- **RChain coordination** — capabilities, jobs, and event channels; the marketplace is a
  coordination primitive.
- **Robotics-as-a-Service** — RChain-driven actuation with work-metered fees.
- **Version control** — Git (GitHub/GitLab/any) and Ariadne (Arweave); AO/Arweave asset upload is
  otherwise dormant.

---

## Architecture

```
Copernicus
├── scripts/
│   ├── core/                  # module.gd, module_registry.gd, task_runner.gd
│   ├── ui/                    # main_shell.gd, ui_theme.gd, command_registry.gd, ...
│   │   ├── cli/               # cli.gd — the terminal command engine
│   │   ├── navigation/        # route.gd, navigation_model.gd
│   │   └── components/        # UiPanel, UiLabel, UiConsole, TerminalInput, ...
│   ├── scenarios/             # the Workbench Loop (scenario.gd, scenario_service.gd, ...)
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

### Key subsystems

- **`ModuleRegistry` + `CopernicusModule`** — backends self-register via `_static_init()`.
- **`CommandRegistry` + `Cli`** — the terminal engine: tokenize → dispatch → `?`-errors.
- **`NavigationModel` + `Route`** — route-based view switching with back + breadcrumb.
- **`ScenarioService` + `ProgressionModel`** — the Workbench Loop ladder.
- **`TaskRunner`** — the single async mechanism (no raw threads, no blocking main-thread I/O).

### Plugin system

A plugin contributes a **view** (a `Route`), **commands** (via `CopernicusModule.get_commands()`),
and/or a **status item**. Nothing opens its own window; plugins are reversible, breadcrumbed, and
styled by `UiTheme` tokens. The **Plugins** view enables/disables them. See the
[plugin guide](docs/development/plugin-guide.md) and the
[terminal developer manual](docs/terminal-developer-manual.md).

## Design decisions

- **Terminal-first** — the terminal is the foundation; the GUI dispatches to the same handlers.
- **Plugin-first** — Editor + Wallet are core; everything else is opt-in.
- **Deterministic rendering** — `docs/spec/06-deterministic-rendering.md`.
- **Formal state transitions** — `docs/spec/05-state-transitions.md`.
- **Honest WYSIWYG** — no inert controls, no lying readouts.

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
godot --headless --script res://scripts/test_cli.gd        # terminal CLI tests
godot --headless --script res://scripts/test_navigation.gd # navigation model
godot --headless --script res://scripts/test_scenarios.gd  # workbench loop
# ... plus test_state, test_shell, test_ik, test_rchain
```

The RChain crypto layer is a Rust GDExtension (`addons/rchain/gdext`); build it with
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

Copernicus is distributed under [GNU AGPLv3](LICENSE). Open source doesn't mean free for all uses —
if you distribute derivative works, you must release your source under AGPL as well.
