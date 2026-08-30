# Copernicus Documentation

Copernicus is an **operating system for robotics** — a small kernel in the middle, apps (plugins) that
run on it, and robots that plug in through ROS 2 and the swappable robotics backends, with a blockchain
+ RaaS layer that takes a design from simulation into the real world.

The **formal specification** is the centre of gravity. Everything below hangs off it.

---

## The kernel

- [`spec/00-kernel.md`](spec/00-kernel.md) — the kernel and its three layers (kernel / plugins /
  backends), and the mission.

The kernel's five components:

- [`spec/07-terminal.md`](spec/07-terminal.md) — the terminal (the shell and the log).
- [`spec/08-viewport.md`](spec/08-viewport.md) — the 3D viewport.
- [`spec/09-screen-schema.md`](spec/09-screen-schema.md) — the windowing (the screen schema).
- [`spec/10-ai-assistant.md`](spec/10-ai-assistant.md) — the agentic AI assistant.
- [`spec/11-wallet-raas.md`](spec/11-wallet-raas.md) — the wallet and robotics-as-a-service.

Supporting specs: `01` Godot model · `02` inventory · `03` signal backbone · `04` components ·
`05` state transitions · `06` deterministic rendering.

## Operating the machine

- [User manual](interface-user-manual.md) — the readable form of the kernel spec.
- [Terminal manual](terminal-user-manual.md) — every verb.
- [Viewport manual](viewport-user-manual.md) — camera, selection, modes, shortcuts.
- [AI assistant manual](ai-assistant-user-manual.md).
- [Feature index](features.md) — one line per feature, grouped by layer.
- [Case studies](case-study-robot-arm.md) — the arm and the TurtleBot, end to end.

## Plugging in robots

- [`spec/13-backend-interface.md`](spec/13-backend-interface.md) — how backends plug into the kernel.
- [`spec/12-plugins.md`](spec/12-plugins.md) — how UI apps mount on the kernel.
- [Physics backends](physics/backends.md) · [Sensors](sensors/overview.md) · [Navigation](navigation/planners.md)
  · [IK solvers](navigation/ik-solvers.md) · [Reinforcement learning](rl/overview.md) ·
  [Industrial robots](industrial/overview.md) · [Omniverse / USD](omni/overview.md) ·
  [ROS 2 bridge](ros2/bridge.md) · [ROS2 native](ros2_native/overview.md).
- [URDF import](robots/urdf-import.md) · [Robot control](robots/control.md).

## The economic layer

- [Wallet + RaaS](spec/11-wallet-raas.md) · [RChain coordination](rchain/design.md) ·
  [Marketplace](blockchain/marketplace.md).

## Development

- [Design philosophy](design-philosophy.md) · [Architecture](03-architecture.md) ·
  [Concepts](02-concepts.md) · [Getting started](01-getting-started.md) · [Quick start](quick-start.md).
- [Plugin guide](development/plugin-guide.md) · [Terminal developer manual](terminal-developer-manual.md) ·
  [Testing](testing.md).
