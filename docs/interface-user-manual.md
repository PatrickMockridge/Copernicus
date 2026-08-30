# Copernicus — User Manual

This manual explains Copernicus from its centre outward. First the **kernel** — the small, fixed piece
everything else attaches to — then the **spec** that defines it, then how you **operate** the machine,
how a **robot plugs in**, and how the **economic layer** takes a design into the real world.

---

## 1. The kernel

Copernicus is an **operating system for robotics**. In the middle is a small, fixed **kernel**; around
it are **apps** you run, and **robots** you plug in — the same shape as Linux.

| The kernel is… | its job |
|---|---|
| the **viewport** | the display — where the robot is drawn |
| the **terminal** | the shell — the command line and the log |
| the **screen schema** | the windowing — how surfaces are arranged |
| the **AI assistant** | the agent — an assistant that edits files for you |
| the **wallet + RaaS** | identity and money — who you are, and how a design earns |

The kernel is always present. It doesn't depend on any app or any robot. On top of it run the **apps**
(plugins): the robot library, the marketplace, coordination, version control, RaaS. And into it plug the
**robots**, through ROS 2 and the swappable robotics backends (physics, IK, sensors, navigation, RL,
industrial, Omniverse).

That is why it is called **Copernicus**: it centres robotics development — open source, no corporate
lock-in, every feature in one place, and a path from a design in simulation to a robot in the real world.

## 2. The spec

The kernel is not a vague idea; it is defined in a **formal specification**. That spec is the centre of
gravity for the whole project — every feature is classified relative to it:

- [`spec/00-kernel.md`](spec/00-kernel.md) — the kernel and the three layers (kernel / plugins /
  backends).
- `07` terminal, `08` viewport, `09` screen schema, `10` AI assistant, `11` wallet + RaaS — the kernel's
  five components.
- `12` plugins — how apps mount on the kernel.
- `13` backend interface — how robots plug in.

This manual is the readable form of that spec. When in doubt about what something is, the spec is the
answer.

## 3. Operating the machine

You operate the machine the way you operate a computer: through the **terminal** (the shell), the
**screens** (the windows), and the **apps**.

### The terminal

The terminal is the shell. Every operation is a **verb**, and the GUI just types those verbs for you.

```
> list            # every command, grouped by category
> help load       # what one command does
> clear           # wipe the screen
```

Errors are loud: an unknown command answers `?UNKNOWN COMMAND`. The terminal is also the **log** — it
records everything you did, at the bottom of the window, always.

### The screens

The left rail is the window switcher. Each icon is a screen; open one by clicking it, or with `open`:

```
> open editor        > open robots       > open wallet
> open marketplace   > open coordination > open vcs
> open raas          > open settings
```

`back` (or the ◀ button) returns you to where you were; the breadcrumb in the status bar shows the path.

### Loading and looking at a robot

```
> load arm6        # a 6-DOF arm
> load turtlebot   # a differential-drive base
> load quadruped   # a legged robot
> load drone       # an aerial robot
```

Look around with the mouse — **left-drag** orbits, **middle-drag** (or `WASD`) pans, the **wheel** zooms.
`wireframe on` shows the skeleton; `grid off` hides the floor.

### The apps (plugins)

The apps are opt-in surfaces on the kernel: the **Robots** library (load a built-in robot), the
**Marketplace** (buy/sell/list designs), **Coordination** (register robots and take jobs), **Version
Control** (git for your work), and **RaaS** (robotics-as-a-service demos). Each can be enabled or
disabled from the **Plugins** view.

### The objective

The **Workbench Loop** is a ten-step progression in the side bar — from **First Light** to **Ship**. Each
step is an objective with a checklist; complete it and the next unlocks. `mode` prints where you are.
Worked end-to-end in the [arm](case-study-robot-arm.md) and [TurtleBot](case-study-turtlebot.md) case
studies.

## 4. Plugging in robots

A robot plugs into the kernel through **ROS 2** and the **swappable backends**.

- **Sensors** — `sensors <lidar|camera|imu> [on|off]` turns on the LIDAR / camera / IMU.
- **Inverse kinematics** — `tool ik`; the toolbar **Reach** button solves the arm to a target.
- **Physics** — `tool physics` (Godot native, PyBullet, CUDA).
- **Navigation** — `tool nav` (A*, Nav2).
- **Reinforcement learning** — `tool gpu` (DQN/PPO/SAC).
- **Industrial robots** — `tool industrial` (MOTOMAN, OPC-UA).
- **Omniverse / USD** — `tool omni`.
- **ROS 2 bridge** — `ros2` connects the bridge, which publishes `/robot/odom`, `/robot/scan`,
  `/robot/image_raw`, `/robot/imu` and subscribes to `/robot/cmd_vel`.

The backends are not hard-wired into the kernel; they register as modules and are selected by `tool`,
exactly as the spec (`13`) requires. The kernel hands a backend the robot tree and the task runner; the
backend hands back signals on the main thread.

## 5. The economic layer

The wallet is your on-chain identity — the second surface after the editor, because it holds funds. You
create a key or import one (`open settings` → Blockchain wallet).

RaaS is the monetisation path: **register** a robot, **publish** a job, **claim** it, and **settle** a
work-metered fee — the same primitive as the marketplace (listing a design = issuing a capability;
purchasing it = transferring it). This is how a design in simulation becomes a robot earning in the real
world.

```
> register arm6
> publish "pick and place"
> claim <job> arm6
> settle arm6 0.5
```

---

## Where to go next

- [`spec/00-kernel.md`](spec/00-kernel.md) — the anchor.
- [Terminal manual](terminal-user-manual.md) — every verb.
- [Viewport manual](viewport-user-manual.md) — camera, selection, modes, shortcuts.
- [AI assistant manual](ai-assistant-user-manual.md).
- [Feature index](features.md) — one line per feature, grouped by layer.
- [Case studies](case-study-robot-arm.md) — the arm and the TurtleBot, end to end.
