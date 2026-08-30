# Copernicus — Features

This is the index of everything Copernicus can do, and how to do it. Each feature has two parts:

- **Use** — the terminal verbs, rail screens, menus, and buttons that drive it.
- **Implement** — the key files behind it, so you can read or extend the code.

For a tour of the overall layout, see the [interface manual](interface-user-manual.md). For the two
end-to-end walkthroughs, see the [Arm6 case study](case-study-robot-arm.md) and the
[TurtleBot case study](case-study-turtlebot.md). Deeper design docs are linked from each section.

---

## 1. Robot library

Five built-in robots, grouped by category.

| id | robot | type |
|---|---|---|
| `turtlebot` | TurtleBot4 | mobile (differential drive) |
| `arm6` | Arm6 | 6-DOF arm + gripper |
| `quadruped` | Quadruped | 12-DOF legged |
| `gripper` | Parallel Gripper | 2 prismatic fingers |
| `drone` | QuadDrone | aerial (4 rotors + camera) |

**Use:** `load <id>` (e.g. `load arm6`), or the **Robots** rail screen.

**Implement:** `scripts/robots/robot_library.gd` (autoload `RobotLibrary`), `robot_factory.gd` (joint/box/
cylinder helpers), `scripts/robots/factories/` (`arm_factory.gd`, `turtlebot_factory.gd`, …).

## 2. URDF / MJCF import

Import an external robot description into the 3D scene.

**Use:** `load <path.urdf|path.mjcf>`, or File → **Open Robot…** (filters `.urdf`, `.mjcf`), or the
Robots screen's **Import URDF/MJCF…** button.

**Implement:** `scripts/urdf_to_godot.gd` (`URDFToGodot.parse`), `scripts/mjcf_to_godot.gd`
(`MJCFToGodot`), `scripts/mesh/` (STL/OBJ/DAE → `ArrayMesh` via `MeshTranslator`),
`scripts/urdf_to_physics.gd`. → [URDF import guide](robots/urdf-import.md)

## 3. Viewport / editor

The 3D robot view: orbit/pan/zoom, select, translate/rotate, render modes.

**Use:** left-drag orbit · middle-drag pan · wheel zoom · left-click select · `Ctrl+1/2/3` modes ·
`wireframe` / `grid` · right-click context menu · `Ctrl+R` toggles meshes. Shortcuts live in
`user://shortcuts.json`.

**Implement:** `scripts/robot_viewer_controller.gd`, `scripts/composite_workspace.gd`,
`scripts/ui/viewport_toolbar.gd`, `scripts/viewport/shortcut_manager.gd`, `scripts/viewport/gizmo.gd`.
→ [Viewport manual](viewport-user-manual.md), [spec 08](spec/08-viewport.md)

## 4. Inverse kinematics (CCD / FABRIK / MoveIt)

Make the arm's end-effector reach a target.

**Use:** `tool ik` (or Tools → Inverse Kinematics…) to pick a solver; the viewport **Reach** button runs
`solve_ik_to_target()` and **Zero** returns all joints to 0.

**Implement:** `scripts/ik/ik_solver.gd` (abstract), `analytical_ik_solver.gd` (CCD + FABRIK),
`moveit_ik_bridge.gd` (+ `moveit_bridge.py`), and the viewer's built-in CCD in
`scripts/robot_viewer_controller.gd` `solve_ik_to_target`. → [IK solvers](navigation/ik-solvers.md)

## 5. Physics backends

Swap physics engines: Godot-native (Jolt), PyBullet, PyBullet-CUDA.

**Use:** `tool physics` (or Tools → Physics Backend…).

**Implement:** `scripts/physics/physics_backend.gd` (abstract), `godot_physics_backend.gd`,
`pybullet_backend.gd` (+ `pybullet_bridge.py`), `scripts/urdf_to_physics.gd`. → [Physics backends](physics/backends.md)

## 6. Sensors

LIDAR, camera frustum, IMU axes, and domain randomization.

**Use:** `sensors <lidar|camera|imu> [on|off]`, or View → **Sensors**, or the viewport right-click menu.

**Implement:** `scripts/lidar_debug.gd` (`LidarDebug` 360-ray), `scripts/camera_debug.gd`,
`scripts/imu_debug.gd`, `scripts/sensors/domain_randomizer.gd`; ROS2-side sensors in
`addons/godot_ros2/sensors/` and `addons/gpu_sensors/`. → [Sensors overview](sensors/overview.md)

## 7. ROS 2 bridge

Stream sensor data and drive the robot over ROS 2.

**Use:** `ros2` (or Tools → ROS2 Connect). Publishes `/robot/odom`, `/robot/scan`, `/robot/image_raw`,
`/robot/imu`; subscribes to `/robot/cmd_vel`.

**Implement:** `addons/godot_ros2/godot_ros2.gd` (autoload `GodotROS2`), `addons/ros2_native/`.
→ [ROS2 bridge](ros2/bridge.md), [native rclpy](ros2_native/overview.md)

## 8. Navigation (A* / Nav2)

Plan paths across an occupancy grid.

**Use:** `tool nav` (or Tools → Navigation…).

**Implement:** `scripts/nav/nav_planner.gd` (abstract), `astar_grid_planner.gd`, `nav2_bridge.gd`,
`occupancy_grid.gd`, `path_visualizer.gd`. → [Planners](navigation/planners.md)

## 9. Reinforcement learning (DQN / PPO / SAC / Isaac Gym)

Train robot policies on the GPU.

**Use:** `tool gpu` (or Tools → GPU / RL Training…).

**Implement:** `scripts/gpu/gpu_backend.gd` (abstract), `backends/pytorch_learner.gd` (DQN),
`backends/ppo_learner.gd`, `backends/sac_learner.gd`, `backends/multi_robot_trainer.gd`,
`backends/isaac_gym/`. → [RL overview](rl/overview.md), [DQN](rl/dqn.md), [PPO/SAC](rl/ppo-sac.md)

## 10. Industrial robots (MOTOMAN / ABB / OPC-UA)

Connect to and command real industrial arms.

**Use:** `tool industrial` (or Tools → Industrial Backends…).

**Implement:** `scripts/industrial/industrial_controller.gd`, `addons/industrial/backends/`
(`motoman_bridge.gd`, `opcua_bridge.gd`). → [Industrial overview](industrial/overview.md)

## 11. Omniverse / USD

Import/export USD and sync to Omniverse Kit.

**Use:** `tool omni` (or Tools → Omniverse / USD…).

**Implement:** `addons/omni/core/` (`usd_importer.gd`, `usd_exporter.gd`), `addons/omni/connectors/`.
→ [Omniverse overview](omni/overview.md)

## 12. Marketplace

Buy, sell, and list robot designs (defaults to RChain).

**Use:** `open marketplace`, or `listings` / `search <query>` / `buy <id>`.

**Implement:** `scripts/marketplace/marketplace_core.gd`, `backends/rchain_marketplace.gd`,
`ui/marketplace_panel.gd`. → [Marketplace](blockchain/marketplace.md)

## 13. Coordination (RChain)

Register robots and coordinate on-chain work.

**Use:** `open coordination`, or `register <robot>` / `publish <job>` / `claim <job> <robot>` /
`settle <robot> <fee>`.

**Implement:** `scripts/coordination/coordination_core.gd`, `rchain_coordination.gd`, backed by
`scripts/rchain/` (`RChainService`, `rchain_wallet.gd`, `rnode_client.gd`). → [Coordination design](rchain/design.md)

## 14. Version control (Git / Ariadne)

Version your designs with git (or Ariadne on Arweave).

**Use:** `open vcs`, or `status` / `log` / `commit <message>` / `push` / `pull` / `clone <url>`.

**Implement:** `scripts/vcs/vcs_backend.gd` (abstract), `git_vcs.gd`, `ariadne_vcs.gd`, `ui/vcs_panel.gd`.

## 15. Wallet

Your identity and funds (RChain).

**Use:** `open wallet`, or the **Wallet** rail screen; create/unlock, import a private key or mnemonic,
transfer, and check balance. Import is also in Settings.

**Implement:** `scripts/rchain/rchain_wallet.gd`, `scripts/rchain/ui/wallet_panel.gd`,
`addons/rchain/RChainCrypto.gd`. → [Wallet spec](rchain/wallet-spec.md)

## 16. AI assistant

The agentic Claude assistant that edits a user workspace.

**Use:** `open ai`, or the viewport top-right **AI** button, or Tools → **AI Assistant**. Configure the
key/endpoint/model/workspace in Settings.

**Implement:** `scripts/ai/agent.gd` (agentic loop), `scripts/ai/anthropic_client.gd`,
`scripts/ai/tools.gd` (read/write/edit/list/search), `scripts/main.gd`. → [AI manual](ai-assistant-user-manual.md)

## 17. Plugins + Settings

Enable/disable plugin views; set AI config and import a wallet key.

**Use:** `plugins` (or `open plugins`); `open settings` (or File → Settings…).

**Implement:** `scripts/ui/main_shell.gd` (`_build_plugins`, `_set_plugin_enabled`),
`scripts/ui/settings_panel.gd`, `scripts/core/settings_store.gd`. Plugin enable state persists to
`user://plugins.json`; settings to `user://settings.json`.

## 18. The Workbench Loop

A 10-step progression from first light to a shipped, validated design. The side bar shows the active
objective and its checklist.

1. **First Light** — load a robot (`robot_loaded`)
2. **Set the Pose** — zero the arm (`all_joints_zeroed`)
3. **Reach the Target** — IK the end-effector to the marker (`end_effector_reached`)
4. **See What It Sees** — turn on all sensors (`lidar/camera/imu_active`)
5. **Make It Move** — drive the base (`robot_moved`)
6. **Wire It to ROS2** — connect the bridge (`ros2_connected`)
7. **Register It** — register on-chain (`robot_registered`)
8. **Put It On the Market** — list a design (`listing_created`)
9. **Run It For Hire** — fund/claim/execute/settle a job (`work_settled`)
10. **Ship** — a validated, published design (`all_stages_complete`)

**Implement:** `scripts/scenarios/scenario_service.gd` (autoload `ScenarioService`), `scenario.gd`,
`progression_model.gd`, `scenario_evaluator.gd`.

## 19. Demos

**Use:** `demo physics` (WASD differential drive) or `demo turtle` (click-to-drive).

**Implement:** `scenes/physics_demo.tscn` / `scripts/physics_demo.gd`, `scenes/turtle_demo.tscn` /
`scripts/turtle_demo.gd`, `scripts/turtle/turtle_controller.gd`.

---

## Further reading

- [Interface manual](interface-user-manual.md) — the layout and verb-first logic.
- [Terminal manual](terminal-user-manual.md) — every command.
- [Terminal developer manual](terminal-developer-manual.md) — how to add commands.
- [Plugin guide](development/plugin-guide.md) — how to add a backend module.
- [Architecture](03-architecture.md), [Design philosophy](design-philosophy.md).
