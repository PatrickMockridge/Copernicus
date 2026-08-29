# Copernicus — Handover Note (2026-08-29)

## Project

Copernicus is a Godot 4.4 robot-design interface (`~/Godot/Godot_4_Robotic_Design_Interface`).
Its purpose (per `CLAUDE.md`): a fast 3D editor for visualizing robot models (URDF/MJCF), an
interactive tool for testing joint configurations, a ROS2 data source, and a viewer that exports to
full simulators / publishes to a marketplace.

## The core problem this session exposed

The codebase has **substantial backend capability that was never wired to the UI**. A "UI makeover"
was done first (cosmetic: theme, fonts, sidebar shell), then a functional audit revealed the real
gap: `load_urdf` had no UI entry point, sensor debuggers were never attached, every tool selector was
orphaned, ROS2 connect was never called, and the joint sliders only spun 2 floating demo wheels on
the wrong axis.

## What is now done (all committed and pushed to `origin/master`)

- **Desktop shell**: `scripts/ui/main_shell.gd` — top menu bar (File / View / Tools / Help) + left
  sidebar nav + content host. Main scene is `scenes/main.tscn`.
- **Menu bar**:
  - File → Open Robot… (FileDialog, URDF/MJCF), Exit.
  - View → Reset View, Wireframe, Grid, Domain Randomization, Sensors ▸ (Lidar / Camera / IMU).
  - Tools → IK / Physics / Navigation / GPU-RL / Omniverse / Industrial selectors, ROS2 Connect,
    Physics Demo, Turtle Demo.
  - Help → About.
- **Viewer context menu**: right-click the 3D viewport opens a PopupMenu (click-vs-drag detected in
  `robot_viewer_controller.gd`).
- **Viewer correctness**: `robot_viewer_controller.gd` — orbit camera fixed (Godot 4 `relative`
  API), camera views from above (pitch +30), demo wheels touch ground and roll about their axle.
- **Joint control**: `urdf_to_godot.gd` stores joint `type` + `axis` as metadata; `set_joint_rotation`
  rotates about the axis (revolute) or translates (prismatic); `_collect_joints` matches by
  type/meta not name. Sample arm at `assets/urdf/sample_arm.urdf`.
- **Sensors**: `composite_workspace.gd` attaches LidarDebug / CameraDebug / ImuDebug, toggled via
  View ▸ Sensors.
- **Coordination backend selector**: `scenes/rchain/coordination_selector.tscn` + a "Backend" button
  in `coordination_panel.gd`.
- **Theme**: `scripts/ui/copernicus_theme.gd` + `resources/themes/copernicus_theme.tres` — modern
  minimal dark palette, bundled fonts (`assets/fonts/`), component helpers.
- **Python fix**: `scripts/gpu/pytorch_learning_node.py` — added missing `Dict` import and removed a
  `@dataclass` on `QNetwork` that broke `nn.Module`.

Recent commits (newest first): `9f36261`, `5d917c8`, `b1dd123`, `9c90ff3`, `a3d350f`, `b201adb`,
`89cec86`, `ceb0c2b`, `4b0c942`.

## Refactor status (2026-08-29) — IDE shell, terminal look, rholang-only

The "pending work" below is now **done** as part of a from-scratch UI refactor (plan:
`~/.claude/plans/linked-roaming-lynx.md`). The shell is now a **VS Code-style IDE for robots**:

- `scripts/ui/main_shell.gd` — Activity Bar (Viewer/Robots/Marketplace/Wallet/Coordination/RaaS/
  Extensions) + Side Bar + editor tabs + bottom terminal + status bar; command palette (`` ` `` /
  `Ctrl+Shift+P` / `Ctrl+K`). RaaS opens in-place (no scene swap).
- `scripts/ui/command_registry.gd` (autoload `CommandRegistry`) + `command_palette.gd` +
  `modal_layer.gd`. Selectors extend `BaseSelector`→`ModalLayer` (dimmed backdrop) and preload their
  backends.
- `scripts/ui/copernicus_theme.gd` + `.tres` — stark-terminal theme (bg `#0a0a0c`, cyan `#7ce`,
  JetBrains Mono, square corners).
- `scripts/robots/` — `robot_library.gd` (autoload) + `robot_factory.gd` + `factories/*.gd`
  (turtlebot/arm/quadruped/gripper/drone) + `ui/robot_gallery.gd`.
- `scripts/rchain/rchain_wallet.gd` + `ui/wallet_panel.gd` — password keystore, auto-gen key,
  lock/unlock. No plaintext field by default.
- Marketplace/publish default to RChain; AO/Arweave dormant except plain `Storage` upload.

**Follow-ups:** BIP-39 mnemonic in the Rust crate (no recovery phrase yet); Physics/Turtle demos
still `change_scene_to_file`; AO code kept dormant (not deleted).

## Key files

- Shell / menus: `scripts/ui/main_shell.gd`
- Viewer: `scripts/robot_viewer_controller.gd`, `scripts/composite_workspace.gd`
- URDF: `scripts/urdf_to_godot.gd`, `scripts/mjcf_to_godot.gd`
- Joint panel: `scripts/joint_panel.gd`
- Sensors: `scripts/lidar_debug.gd`, `scripts/camera_debug.gd`, `scripts/imu_debug.gd`
- Theme: `scripts/ui/copernicus_theme.gd`, `resources/themes/copernicus_theme.tres`
- Selectors: `scripts/ui/base_selector.gd`, `scripts/{ik,physics,nav,omni,gpu}/**`, `addons/industrial/`
- Wallet/coordination: `scripts/rchain/ui/{wallet_panel,coordination_panel}.gd`, `scripts/coordination/`
- Marketplace: `scripts/marketplace/ui/marketplace_panel.gd`

## Verification commands

```bash
godot --headless --import                                      # clean parse/import
godot --headless --script res://scripts/test_rchain.gd          # RChain regression (ALL PASS)
godot --headless --quit-after 6 res://scenes/main.tscn          # shell smoke (no errors)
godot res://scenes/main.tscn                                    # launch the app (has GPU on :0)
```

## Gotchas (important)

- Autoload names (`EnvService`, `CopernicusTheme`, `ModuleRegistry`, `RChainService`) are NOT global
  identifiers in `--script` mode — use `OS.get_environment()` there.
- `_static_init` is the module-registration pattern; it only runs when the script is loaded, so any
  selector whose backends aren't preloaded shows up empty.
- Godot 4 input: `InputEventMouseMotion.relative` is a `Vector2` (no `relative_x`/`relative_y`).
- The RChain crypto/SDK/coordination work is exercised by `test_rchain.gd` — don't regress it.
- `~/RWallet` (TypeScript RChain wallet) and `~/RNodeRust` (RChain node) are reference repos for the
  RChain coordination layer.
