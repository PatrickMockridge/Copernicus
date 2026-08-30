# Case Study — the Arm6 (6-DOF robot arm)

This walks through loading Copernicus's built-in 6-DOF arm and using it end-to-end: inspect it, set a
pose, solve inverse kinematics to reach a target, turn on sensors, and wire it to ROS 2. It doubles as
the first three steps of the Workbench Loop.

## 1. Load the arm

In the terminal (the bottom console), type:

```
> load arm6
```

This calls `RobotLibrary.build("arm6")` → `ArmFactory.build()`, which builds a serial chain of six
revolute joints plus a two-finger gripper, ending in a red **`ee_link`** sphere — the end-effector that
inverse kinematics tracks.

The joint tree is:

```
base_link → joint_1 → link_1 → joint_2 → link_2 → joint_3 → link_3
          → joint_4 → link_4 → joint_5 → link_5 → joint_6 → link_6
          → flange
          → gripper_left / gripper_right (2 finger joints)
          → ee_link (the tracked end-effector)
```

`joint_1` rotates about Y; `joint_2`/`joint_3`/`joint_5` about Z; `joint_4`/`joint_6` about X. All main
joints have limits −180°…180°; the two gripper fingers are ±45°.

## 2. Inspect it

- **Orbit** with left-drag, **zoom** with the wheel, **pan** with middle-drag or `WASD`.
- `wireframe on` switches to the flat debug look; `grid off` hides the ground grid.
- Left-click a link to select it (it highlights); click empty space to deselect.

## 3. Set the pose

The **Zero** button on the viewport toolbar returns every joint to 0°. This is what the Workbench Loop's
**Set the Pose** scenario checks.

```
> mode          # shows the active scenario and mode
```

Zeroing all joints emits `joints_zeroed`, which marks the scenario check `all_joints_zeroed`.

## 4. Reach the target

A green **target marker** floats in the scene. The **Reach** button runs `solve_ik_to_target()`, a
built-in CCD loop that rotates each arm joint (tip → base, skipping the `gripper_*` joints) until
`ee_link` is within 2 cm of the marker.

- Move the target: `RobotViewerController.set_target_position(...)` (there is no terminal verb for this).
- When `ee_link` is within 5 cm, the viewer emits `target_reached`, satisfying the **Reach the Target**
  scenario (`end_effector_reached`).

For the selectable solver layer (CCD/FABRIK/MoveIt), use `tool ik` or Tools → Inverse Kinematics….

## 5. Sensors

```
> sensors camera on
> sensors imu on
```

This turns on the camera-frustum and IMU-axis debug overlays and marks `camera_active`/`imu_active`.

## 6. Wire it to ROS 2

```
> ros2
```

Connects the bridge (Tools → **ROS2 Connect** does the same) and marks `ros2_connected`.

## Implementation notes

- **Model:** `scripts/robots/factories/arm_factory.gd` (`ArmFactory.build()`); joint metadata
  (`joint_type`, `joint_axis`, `has_limits`, `limit_lower/upper`) is stamped by
  `scripts/robots/robot_factory.gd`.
- **Viewer IK:** `scripts/robot_viewer_controller.gd` — `solve_ik_to_target()`, `zero_all_joints()`,
  `_find_end_effector()` (looks for `ee_link`), `_check_target_reached()`.
- **Solver layer:** `scripts/ik/` — `ik_solver.gd` (abstract), `analytical_ik_solver.gd` (CCD + FABRIK),
  `moveit_ik_bridge.gd`.
- **Scenarios:** `scripts/scenarios/scenario_service.gd` — `set_the_pose` and `reach_the_target` both
  auto-load Arm6 on activation.
- **Signals → scenario:** `joints_zeroed` and `target_reached` are wired to `ScenarioService` context
  in `scripts/ui/main_shell.gd`.

See also: [features](features.md), [IK solvers](navigation/ik-solvers.md), [viewport manual](viewport-user-manual.md).
