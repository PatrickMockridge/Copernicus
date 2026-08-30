# Copernicus — Features

Everything Copernicus can do, grouped by the kernel's three layers (see
[`spec/00-kernel.md`](spec/00-kernel.md)). Each entry has **Use** (the verbs/buttons) and
**Implement** (the key files).

---

## Kernel

The fixed, always-present core.

### Viewport / editor

The 3D robot view: orbit/pan/zoom, select, translate/rotate, render modes.

**Use:** left-drag orbit · middle-drag pan · wheel zoom · left-click select · `Ctrl+1/2/3` modes ·
`wireframe` / `grid` · right-click context menu · `Ctrl+R` toggles meshes.

**Implement:** `scripts/robot_viewer_controller.gd`, `scripts/composite_workspace.gd`,
`scripts/ui/viewport_toolbar.gd`, `scripts/viewport/shortcut_manager.gd`, `scripts/viewport/gizmo.gd`.
→ [Viewport manual](viewport-user-manual.md), [spec 08](spec/08-viewport.md)

### Terminal

The verb-first command line and the log.

**Use:** `list`, `help <command>`, and the built-in verbs (`open`, `load`, `wireframe`, `grid`, `sensors`,
`tool`, `ros2`, `plugins`, …).

**Implement:** `scripts/cli/cli.gd`, `scripts/ui/command_registry.gd`, `scripts/ui/components/ui_console.gd`.
→ [Terminal manual](terminal-user-manual.md), [spec 07](spec/07-terminal.md)

### Wallet

Your identity and funds (RChain).

**Use:** `open wallet`; create/unlock, import a private key or mnemonic, transfer, check balance. Import
is also in Settings.

**Implement:** `scripts/rchain/rchain_wallet.gd`, `scripts/rchain/ui/wallet_panel.gd`,
`addons/rchain/RChainCrypto.gd`. → [Wallet spec](rchain/wallet-spec.md)

### AI assistant

The agentic Claude assistant that edits a user workspace.

**Use:** `open ai`, or the viewport top-right **AI** button, or Tools → **AI Assistant**. Configure the
key/endpoint/model/workspace in Settings.

**Implement:** `scripts/ai/agent.gd`, `scripts/ai/anthropic_client.gd`, `scripts/ai/tools.gd`,
`scripts/main.gd`. → [AI manual](ai-assistant-user-manual.md), [spec 10](spec/10-ai-assistant.md)

### Plugins + Settings

Enable/disable plugin views; set AI config and import a wallet key.

**Use:** `plugins`; `open settings` (or File → Settings…).

**Implement:** `scripts/ui/main_shell.gd`, `scripts/ui/settings_panel.gd`,
`scripts/core/settings_store.gd`. State persists to `user://plugins.json` and `user://settings.json`.

---

## Apps (plugins)

Opt-in surfaces mounted on the kernel.

### Robot library

Five built-in robots. `load <id>` (e.g. `load arm6`), or the **Robots** rail screen.

**Implement:** `scripts/robots/robot_library.gd` (autoload `RobotLibrary`), `robot_factory.gd`,
`scripts/robots/factories/` (`arm_factory.gd`, `turtlebot_factory.gd`, …).

### URDF / MJCF import

`load <path.urdf|path.mjcf>`, or File → **Open Robot…**, or the Robots screen's **Import** button.

**Implement:** `scripts/urdf_to_godot.gd`, `scripts/mjcf_to_godot.gd`, `scripts/mesh/`,
`scripts/urdf_to_physics.gd`. → [URDF import guide](robots/urdf-import.md)

### Marketplace

Buy, sell, and list designs (defaults to RChain). `open marketplace`, or `listings` / `search <query>` /
`buy <id>`.

**Implement:** `scripts/marketplace/marketplace_core.gd`, `backends/rchain_marketplace.gd`,
`ui/marketplace_panel.gd`. → [Marketplace](blockchain/marketplace.md)

### Coordination (RChain)

Register robots and coordinate work on-chain. `open coordination`, or `register` / `publish` / `claim` /
`settle`.

**Implement:** `scripts/coordination/coordination_core.gd`, `rchain_coordination.gd`, backed by
`scripts/rchain/`. → [Coordination design](rchain/design.md)

### Version control (Git / Ariadne)

Version your designs. `open vcs`, or `status` / `log` / `commit <message>` / `push` / `pull` / `clone`.

**Implement:** `scripts/vcs/vcs_backend.gd` (abstract), `git_vcs.gd`, `ariadne_vcs.gd`, `ui/vcs_panel.gd`.

---

## Robots (backends)

Swappable robotics capability, selected with `tool <x>`.

### Inverse kinematics (CCD / FABRIK / MoveIt)

**Use:** `tool ik`; the viewport **Reach** button runs `solve_ik_to_target()`, **Zero** zeroes joints.

**Implement:** `scripts/ik/ik_solver.gd`, `analytical_ik_solver.gd`, `moveit_ik_bridge.gd`. → [IK solvers](navigation/ik-solvers.md)

### Physics

Godot-native (Jolt), PyBullet, PyBullet-CUDA. **Use:** `tool physics`.

**Implement:** `scripts/physics/physics_backend.gd`, `godot_physics_backend.gd`, `pybullet_backend.gd`. → [Physics backends](physics/backends.md)

### Sensors

LIDAR, camera, IMU, domain randomization. **Use:** `sensors <lidar|camera|imu> [on|off]`.

**Implement:** `scripts/lidar_debug.gd`, `scripts/camera_debug.gd`, `scripts/imu_debug.gd`,
`addons/godot_ros2/sensors/`, `addons/gpu_sensors/`. → [Sensors overview](sensors/overview.md)

### Navigation (A* / Nav2)

**Use:** `tool nav`.

**Implement:** `scripts/nav/nav_planner.gd`, `astar_grid_planner.gd`, `nav2_bridge.gd`. → [Planners](navigation/planners.md)

### Reinforcement learning (DQN / PPO / SAC)

**Use:** `tool gpu`. (Isaac Gym is experimental.)

**Implement:** `scripts/gpu/gpu_backend.gd`, `backends/pytorch_learner.gd` (DQN), `backends/ppo_learner.gd`,
`backends/sac_learner.gd`. → [RL overview](rl/overview.md), [DQN](rl/dqn.md), [PPO/SAC](rl/ppo-sac.md)

### Industrial robots (MOTOMAN / OPC-UA)

**Use:** `tool industrial`.

**Implement:** `scripts/industrial/industrial_controller.gd`, `addons/industrial/backends/`
(`motoman_bridge.gd`, `opcua_bridge.gd`). → [Industrial overview](industrial/overview.md)

### Omniverse / USD

**Use:** `tool omni`.

**Implement:** `addons/omni/core/`, `addons/omni/connectors/`. → [Omniverse overview](omni/overview.md)

### ROS 2 bridge

**Use:** `ros2`. Publishes `/robot/odom`, `/robot/scan`, `/robot/image_raw`, `/robot/imu`; subscribes to
`/robot/cmd_vel`.

**Implement:** `addons/godot_ros2/godot_ros2.gd`, `addons/ros2_native/`. → [ROS2 bridge](ros2/bridge.md)

---

## The Workbench Loop

A 10-step progression from First Light to Ship, shown in the side bar. `mode` prints where you are.

**Implement:** `scripts/scenarios/scenario_service.gd`, `scenario.gd`, `progression_model.gd`,
`scenario_evaluator.gd`. → [Arm case study](case-study-robot-arm.md), [TurtleBot case study](case-study-turtlebot.md)

## Demos

**Use:** `demo physics` (WASD) or `demo turtle` (click-to-drive).

**Implement:** `scripts/physics_demo.gd`, `scripts/turtle_demo.gd`, `scripts/turtle/turtle_controller.gd`.

---

## Further reading

- [Interface manual](interface-user-manual.md) · [Design philosophy](design-philosophy.md) ·
  [Architecture](03-architecture.md).
